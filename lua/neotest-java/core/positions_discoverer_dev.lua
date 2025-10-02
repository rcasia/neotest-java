local lib = require("neotest.lib")
local Tree = require("neotest.types").Tree

local PositionsDiscoverer = {}

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function PositionsDiscoverer.discover_positions(file_path)
	local src = lib.files.read(file_path)

	-- We only need to capture package and test-method names.
	local query = vim.treesitter.query.parse(
		"java",
		[[

    ;; Package declaration
    (program
      (package_declaration
        (scoped_identifier) @package.name
      )?
    )

    ;; Test class
    (class_declaration
      name: (identifier) @class.name
    ) @class.definition

    ;; Annotated test methods
    (method_declaration
      (modifiers
        [
          (marker_annotation
            name: (identifier) @annotation
            (#any-of? @annotation "Test" "ParameterizedTest" "TestFactory" "CartesianTest")
          )
          (annotation
            name: (identifier) @annotation
            (#any-of? @annotation "Test" "ParameterizedTest" "TestFactory" "CartesianTest")
          )
        ]
      )
      name: (identifier) @test.name
    ) @test.definition

  ]]
	)

	local ts_tree = vim.treesitter.get_string_parser(src, "java"):parse()[1]

	-- function just to take the pacakage name
	--- @return string
	local get_package_name = function()
		local result = ""
		for id, node in query:iter_captures(ts_tree:root(), src, 0, -1) do
			local cap = query.captures[id]
			if cap == "package.name" then
				result = (vim.treesitter.get_node_text(node, src) or ""):gsub("%s+", "")
				break
			end
		end
		return result
	end

	local pkg = get_package_name()

	--- @return TSNode
	local get_main_class = function()
		local result = nil
		for id, node in query:iter_captures(ts_tree:root(), src, 0, -1) do
			local cap = query.captures[id]
			if cap == "class.definition" then
				result = node
				break
			end
		end
		return result
	end

	local main_class = get_main_class()

	for id, node in query:iter_captures(ts_tree:root(), src, 0, -1) do
		local cap = query.captures[id]

		if cap == "class.name" then
			-- just to see the class name
			local class_name = vim.treesitter.get_node_text(node, src)
		end

		if cap == "method.name" then
			local method = vim.treesitter.get_node_text(node, src)
			-- climb to enclosing class/inner classes and collect their names
			local parts = {}
			local cur = node
			while cur do
				if
					cur:type() == "class_declaration"
					or cur:type() == "interface_declaration"
					or cur:type() == "enum_declaration"
					or cur:type() == "record_declaration"
				then
					local name_field = cur:field("name")[1]
					if name_field then
						table.insert(parts, 1, vim.treesitter.get_node_text(name_field, src))
					end
				end
				cur = cur:parent()
			end

			local class_bin = table.concat(parts, "$") -- Outer$Inner
			if pkg and pkg ~= "" then
				class_bin = pkg .. "." .. class_bin
			end

			local fqn = string.format("%s#%s", class_bin, method)
			-- print(fqn) -- ==> com.example.Outer$Inner#simpleTestMethod

			method = fqn
		end
	end

	return Tree.from_list({
		{
			id = pkg,
			name = file_path:gsub(".*/", ""),
			path = file_path,
			range = { ts_tree:root():range() },
		},
		{
			{
				id = pkg .. ".Outer",
				name = "Outer",
				path = file_path,
				range = { main_class:range() },
				type = "namespace",
			},
			-- 	{
			-- 		{
			-- 			id = "/tmp/lua_l7nCK1.java::Test::simpleTestMethod",
			-- 			name = "simpleTestMethod",
			-- 			path = "/tmp/lua_l7nCK1.java",
			-- 			range = { 2, 2, 5, 3 },
			-- 			type = "test",
			-- 		},
			-- 	},
		},
	}, function(pos)
		return pos.id
	end)
end

return PositionsDiscoverer
