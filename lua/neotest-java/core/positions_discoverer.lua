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

	-- Utility: DFS to find the first node that represents a "type"
	local type_node_kinds = {
		type_type = true,
		unann_type = true,
		primitive_type = true,
		numeric_type = true,
		integral_type = true,
		class_or_interface_type = true,
	}

	local function find_first_type_node(n)
		if type_node_kinds[n:type()] then
			return n
		end
		for child in n:iter_children() do
			local found = find_first_type_node(child)
			if found then
				return found
			end
		end
		return nil
	end

	local function text(n)
		return vim.treesitter.get_node_text(n, content)
	end

	-- Fallback: extract primitive keyword (incl. boolean) from a parameter node text
	local function fallback_primitive_text(param_node)
		local s = text(param_node)
		if not s or s == "" then
			return nil
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
			return nil
		end

		-- Append any array brackets (e.g., boolean[], int[][])
		local brackets = {}
		for _ in s:gmatch("%[%s*%]") do
			table.insert(brackets, "[]")
		end
		if #brackets > 0 then
			primitive = primitive .. table.concat(brackets, "")
		end

		return primitive
	end

	-- Collect each parameter's type
	local types = {}
	for child in formal_params:iter_children() do
		local kind = child:type()
		if kind == "formal_parameter" or kind == "receiver_parameter" or kind == "last_formal_parameter" then
			local tnode = find_first_type_node(child)
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

			-- Robust fallback for primitives like 'boolean' when TS node text is empty
			if not t then
				t = fallback_primitive_text(child)
			end

			if t then
				-- If it's a vararg parameter, append "..."
				if kind == "last_formal_parameter" and not t:find("%.%.%.$") then
					t = t .. "..."
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
