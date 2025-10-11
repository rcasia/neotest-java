local lib = require("neotest.lib")
local resolve_package_name = require("neotest-java.util.resolve_package_name")

local PositionsDiscoverer = {}

-- Helper: extract parameter type nodes from a method_declaration via Tree-sitter
local function extract_param_types_from_range(content, range)
	local ok, parser = pcall(vim.treesitter.get_string_parser, content, "java")
	if not ok or not parser then
		return {}
	end
	local root = parser:parse()[1]:root()
	local node = root:named_descendant_for_range(range[1], range[2], range[3], range[4])
	if not node then
		return {}
	end

	-- Climb to the method_declaration, if needed
	while node and node:type() ~= "method_declaration" do
		node = node:parent()
	end
	if not node then
		return {}
	end

	-- Find formal_parameters node
	local formal_params = nil
	for child in node:iter_children() do
		if child:type() == "formal_parameters" then
			formal_params = child
			break
		end
	end
	if not formal_params then
		return {}
	end

	-- We prefer the *widest* node that represents the full type, so that arrays include [].
	-- Priority: unann_array_type/array_type > class_or_interface_type > unann_type/unann_primitive_type > primitive/numeric/etc.
	local priority = {
		unann_array_type = 7,
		array_type = 7,
		class_or_interface_type = 6,
		unann_reference_type = 5,
		unann_type = 4,
		unann_primitive_type = 4,
		type_type = 3,
		primitive_type = 2,
		numeric_type = 2,
		integral_type = 2,
		floating_point_type = 2,
	}

	local function best_type_node(n, best, best_p)
		local t = n:type()
		local p = priority[t]
		if p and (not best_p or p > best_p) then
			best, best_p = n, p
		end
		for child in n:iter_children() do
			best, best_p = best_type_node(child, best, best_p)
		end
		return best, best_p
	end

	local function text(n)
		return vim.treesitter.get_node_text(n, content)
	end

	-- Count how many [] are already present in a string
	local function count_brackets(s)
		local c = 0
		for _ in s:gmatch("%[%s*%]") do
			c = c + 1
		end
		return c
	end

	-- Fallback: extract primitive keyword (incl. boolean) from a parameter node text
	local function fallback_primitive_text(param_node)
		local s = text(param_node)
		if not s or s == "" then
			return nil, 0
		end

		-- Try to find a primitive keyword token
		local primitive = s:match("%f[%w](boolean)%f[%W]")
			or s:match("%f[%w](byte)%f[%W]")
			or s:match("%f[%w](short)%f[%W]")
			or s:match("%f[%w](char)%f[%W]")
			or s:match("%f[%w](int)%f[%W]")
			or s:match("%f[%w](long)%f[%W]")
			or s:match("%f[%w](float)%f[%W]")
			or s:match("%f[%w](double)%f[%W]")

		if not primitive then
			return nil, 0
		end

		-- Total dims present in the whole parameter text
		local dims_in_param = count_brackets(s)
		return primitive, dims_in_param
	end

	-- Collect each parameter's type
	local types = {}
	for child in formal_params:iter_children() do
		local kind = child:type()
		if kind == "formal_parameter" or kind == "receiver_parameter" or kind == "last_formal_parameter" then
			-- Prefer the widest node for the type (to include array brackets if part of type)
			local tnode = select(1, best_type_node(child))
			local t = nil

			if tnode then
				t = text(tnode)
				if t then
					t = t:gsub("%s+", " "):gsub("^%s*", ""):gsub("%s*$", "")
					if t == "" then
						t = nil
					end
				end
			end

			local param_full_text = text(child) or ""
			local dims_in_param = count_brackets(param_full_text)

			-- Robust fallback for primitives like 'boolean'
			local fallback_dims = 0
			if not t then
				t, fallback_dims = fallback_primitive_text(child)
			end

			if t then
				-- If it's varargs, prefer "..." and do not add [].
				local is_vararg = (kind == "last_formal_parameter")
				if is_vararg and not t:find("%.%.%.$") then
					t = t .. "..."
				else
					-- Ensure array dims present in the *parameter* are reflected in the type text.
					-- Some grammars yield just "int" as the type node while "[]" is attached to the declarator/dims.
					local dims_in_t = count_brackets(t)
					local missing = math.max(0, dims_in_param - dims_in_t)
					if missing > 0 then
						t = t .. string.rep("[]", missing)
					end
				end

				-- Normalize whitespace just in case
				t = t:gsub("%s+", " "):gsub("^%s*", ""):gsub("%s*$", "")
				table.insert(types, t)
			end
		end
	end

	return types
end

-- Helper: read whole file quickly
local function read_all(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local s = f:read("*a")
	f:close()
	return s
end

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function PositionsDiscoverer.discover_positions(file_path)
	local annotations = { "Test", "ParameterizedTest", "TestFactory", "CartesianTest" }
	local a = vim.iter(annotations)
		:map(function(v)
			return string.format([["%s"]], v)
		end)
		:join(" ")

	local query = [[

    ;; Test class
    (class_declaration
      name: (identifier) @namespace.name
    ) @namespace.definition

    ;; Annotated test methods
    (method_declaration
      (modifiers
        [
          (marker_annotation
            name: (identifier) @annotation
            (#any-of? @annotation ]] .. a .. [[)
          )
          (annotation
            name: (identifier) @annotation
            (#any-of? @annotation ]] .. a .. [[)
          )
        ]
      )
      name: (identifier) @test.name
    ) @test.definition

  ]]

	-- Read file content once so we can reuse for parameter extraction
	local file_content = read_all(file_path) or ""

	return lib.treesitter.parse_positions(file_path, query, {
		require_namespaces = true,
		nested_tests = false,
		position_id = function(position, parents)
			if position.type == "file" or position.type == "dir" then
				return position.path
			end

			local package_name = resolve_package_name(position.path)

			local namespace_string = vim
				.iter(parents)
				--- @param pos neotest.Position
				:filter(function(pos)
					return pos.type == "namespace"
				end)
				:map(function(pos)
					return pos.name
				end)
				:join("$")

			if position.type == "namespace" then
				if namespace_string == "" then
					return package_name ~= "" and (package_name .. "." .. position.name) or position.name
				end
				return package_name ~= "" and (package_name .. "." .. namespace_string .. "$" .. position.name)
					or (namespace_string .. "$" .. position.name)
			end

			-- For test positions: method name + optional "(type, ...)" signature
			local test_name = position.name
			local params = {}
			if file_content ~= "" and position.range then
				local ok, extracted = pcall(extract_param_types_from_range, file_content, position.range)
				if ok and extracted and #extracted > 0 then
					params = extracted
				end
			end

			if #params > 0 then
				test_name = string.format("%s(%s)", test_name, table.concat(params, ", "))
			end

			return package_name ~= "" and (package_name .. "." .. namespace_string .. "#" .. test_name)
				or (namespace_string .. "#" .. test_name)
		end,
	})
end

return PositionsDiscoverer
