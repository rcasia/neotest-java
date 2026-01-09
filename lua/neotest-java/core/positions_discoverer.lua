local lib = require("neotest.lib")
local resolve_package_name = require("neotest-java.util.resolve_package_name")
local Path = require("neotest-java.model.path")
local namespace_id = require("neotest-java.core.namespace_id")
local test_method_id = require("neotest-java.core.test_method_id")

local PositionsDiscoverer = {}

-- -------- Utils --------

local function count_brackets(s)
	local c = 0
	for _ in s:gmatch("%[%s*%]") do
		c = c + 1
	end
	return c
end

-- Fully-qualify parameter types for JUnit selectors
local function normalize_type_for_junit(t, package_name)
	-- trim/collapse
	t = t:gsub("%s+", "")
	-- detect varargs / array dims (strip and re-append later)
	local is_varargs = false
	if t:sub(-3) == "..." then
		is_varargs = true
		t = t:sub(1, -4)
	end
	local dims = 0
	while t:sub(-2) == "[]" do
		dims = dims + 1
		t = t:sub(1, -3)
	end

	-- strip generics
	t = t:gsub("<.->", "")

	local primitives = {
		boolean = true,
		byte = true,
		short = true,
		char = true,
		int = true,
		long = true,
		float = true,
		double = true,
		["void"] = true,
	}
	if primitives[t] then
		if is_varargs then
			dims = dims + 1
		end -- varargs primitive -> primitive[]
		return t .. string.rep("[]", dims)
	end

	local java_lang = {
		String = true,
		Object = true,
		Boolean = true,
		Integer = true,
		Double = true,
		Float = true,
		Long = true,
		Short = true,
		Character = true,
		Byte = true,
		Void = true,
	}
	local java_util = {
		List = true,
		Map = true,
		Set = true,
		Collection = true,
		Iterable = true,
		Deque = true,
		Queue = true,
		Optional = true,
	}

	local function convert_nested_dots_to_dollars(fqn)
		local pkg, classes = fqn:match("^([%l%d_%.]+)%.(.+)$")
		if not pkg then
			if fqn:match("^[A-Z]") then
				return fqn:gsub("%.", "$")
			end
			return fqn
		end
		classes = classes:gsub("%.", "$")
		return pkg .. "." .. classes
	end

	local qualified
	if t:find("%.") then
		local first = t:match("^([%w_]+)")
		if first and first:match("^[a-z]") then
			qualified = convert_nested_dots_to_dollars(t) -- already FQN package
		else
			qualified = (package_name and package_name ~= "" and (package_name .. "." .. t) or t)
			qualified = convert_nested_dots_to_dollars(qualified)
		end
	else
		if java_lang[t] then
			qualified = "java.lang." .. t
		elseif java_util[t] then
			qualified = "java.util." .. t
		elseif package_name and package_name ~= "" then
			qualified = package_name .. "." .. t
		else
			qualified = t
		end
		qualified = convert_nested_dots_to_dollars(qualified)
	end

	if is_varargs then
		dims = dims + 1
	end -- varargs reference -> one extra []
	return qualified .. string.rep("[]", dims)
end

-- Prefer widest type node (arrays > reference > unann > primitive)
local TYPE_PRIORITY = {
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

local function best_type_node(start_node)
	local best, best_p
	local function dfs(n)
		local t = n:type()
		local p = TYPE_PRIORITY[t]
		if p and (not best_p or p > best_p) then
			best, best_p = n, p
		end
		for child in n:iter_children() do
			dfs(child)
		end
	end
	dfs(start_node)
	return best
end

-- -------- Parameter extraction (grammar-agnostic) --------

local function extract_param_types_from_range(content, range)
	local ok, parser = pcall(vim.treesitter.get_string_parser, content, "java")
	if not ok or not parser then
		return {}
	end
	local tree = parser:parse()[1]
	if not tree then
		return {}
	end
	local root = tree:root()

	-- find method_declaration covering the given range
	local node = root:named_descendant_for_range(range[1], range[2], range[3], range[4])
	while node and node:type() ~= "method_declaration" do
		node = node:parent()
	end
	if not node then
		return {}
	end

	local function text(n)
		return (n and vim.treesitter.get_node_text(n, content)) or ""
	end

	-- find formal_parameters node
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

	-- Walk descendants of formal_parameters **in source order**
	-- For any node that has a field("type"), consider that node a parameter-like node.
	local params_nodes = {}
	local function walk(n)
		-- record parameters in source order
		local type_fields = n:field("type")
		if type_fields and #type_fields > 0 then
			table.insert(params_nodes, { pnode = n, tnode = type_fields[1] })
			-- do NOT return; we still want to walk to catch later siblings
		end
		for child in n:iter_children() do
			walk(child)
		end
	end
	walk(formal_params)

	-- Filter out duplicates: some grammars expose intermediary nodes with 'type' fields.
	-- Keep only those whose parent is still inside formal_parameters and whose text contains an identifier/ellipsis.
	local filtered = {}
	for _, pair in ipairs(params_nodes) do
		local pnode, tnode = pair.pnode, pair.tnode
		-- require that the parameter node subtree includes a name or '...'
		local ptxt = text(pnode)
		if ptxt ~= "" and (ptxt:find("...") or ptxt:find("[%w_]%s*[,)]") or ptxt:find("[%w_]%s*$")) then
			table.insert(filtered, { pnode = pnode, tnode = tnode })
		end
	end

	-- Deduplicate by the start byte of the parameter node to keep left-to-right order unique
	table.sort(filtered, function(a, b)
		local ra = { a.pnode:range() }
		local rb = { b.pnode:range() }
		if ra[1] == rb[1] then
			return ra[2] < rb[2]
		end
		return ra[1] < rb[1]
	end)
	local unique = {}
	local seen = {}
	for _, pair in ipairs(filtered) do
		local sr, sc = pair.pnode:range()
		local key = tostring(sr) .. ":" .. tostring(sc)
		if not seen[key] then
			table.insert(unique, pair)
			seen[key] = true
		end
	end

	-- Build type texts with dims/varargs preserved
	local out = {}
	for _, pair in ipairs(unique) do
		local pnode, tnode = pair.pnode, pair.tnode
		-- prefer widest type node under the parameter node
		local widest = best_type_node(pnode) or tnode
		local t = text(widest)
		if t == "" then
			-- defensive primitive fallback from the parameter text
			local s = text(pnode)
			t = s:match("%f[%w](boolean)%f[%W]")
				or s:match("%f[%w](byte)%f[%W]")
				or s:match("%f[%w](short)%f[%W]")
				or s:match("%f[%w](char)%f[%W]")
				or s:match("%f[%w](int)%f[%W]")
				or s:match("%f[%w](long)%f[%W]")
				or s:match("%f[%w](float)%f[%W]")
				or s:match("%f[%w](double)%f[%W]")
				or ""
		end
		if t ~= "" then
			t = t:gsub("%s+", " "):gsub("^%s*", ""):gsub("%s*$", "")

			local ptxt = text(pnode)
			local is_vararg = ptxt:find("%.%.%.", 1, true) ~= nil
			if is_vararg and not t:find("%.%.%.$") then
				t = t .. "..."
			end

			local dims_in_param = count_brackets(ptxt)
			local dims_in_t = count_brackets(t)
			local missing = math.max(0, dims_in_param - dims_in_t)
			if missing > 0 and not t:find("%.%.%.$") then
				t = t .. string.rep("[]", missing)
			end

			table.insert(out, t)
		end
	end

	return out
end

-- -------- I/O helper --------

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

			local package_name = resolve_package_name(Path(position.path))

			if position.type == "namespace" then
				return namespace_id(position, parents, package_name)
			end

			-- For test positions: method name + JUnit-ready "(type, ...)" signature
			local test_name = position.name
			local params = {}
			if file_content ~= "" and position.range then
				local ok, extracted = pcall(extract_param_types_from_range, file_content, position.range)
				if ok and extracted and #extracted > 0 then
					params = extracted
				end
			end

			if #params > 0 then
				local normalized = {}
				for _, p in ipairs(params) do
					table.insert(normalized, normalize_type_for_junit(p, package_name))
				end
				test_name = string.format("%s(%s)", test_name, table.concat(normalized, ", "))

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
				return package_name ~= "" and (package_name .. "." .. namespace_string .. "#" .. test_name)
					or (namespace_string .. "#" .. test_name)
			end

			return test_method_id(position, parents, package_name)
		end,
	})
end

return PositionsDiscoverer
