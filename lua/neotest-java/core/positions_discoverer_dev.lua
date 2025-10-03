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
	--- @return string | nil
	local get_package_name = function()
		local result = nil
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

	--- recursively build list of nodes from TSNode tree
	--- @param node TSNode
	--- @return {id: string, name: string, path: string, range: table}[]
	local function build_tree(node)
		local captures = vim.iter(query:iter_captures(node, src, 0, -1))
			:map(function(id, child)
				return {
					id = id,
					child = child,
				}
			end)
			:totable()

		return vim
			.iter(captures)
			:map(function(c)
				return query.captures[c.id], c.child
			end)
			:filter(function(_, child)
				return not child:parent() or child:parent() == node
			end)
			--- @param child TSNode
			:map(function(cap, child)
				if cap == "package.declaration" then
					return {
						id = pkg or "<no package>",
						name = file_path:gsub(".*/", ""),
						path = file_path,
						range = { node:range() },
					}
				end

				if cap == "class.definition" then
					local name = vim.treesitter.get_node_text(child:field("name")[1], src) or "Unknown"
					local children = vim.iter(child:iter_children()):map(build_tree):totable()
					local children_flattered = vim.iter(children):flatten():totable()

					local inner_classname = name
					local cur = child:parent()
					while cur do
						if cur:type() == "class_declaration" then
							inner_classname = vim.treesitter.get_node_text(cur:field("name")[1], src)
								.. "$"
								.. inner_classname
						end
						cur = cur:parent()
					end

					return {
						{
							id = (pkg and (pkg .. ".") or "") .. inner_classname,
							name = name,
							path = file_path,
							range = { child:range() },
							type = "namespace",
						},
						{ unpack(children_flattered) },
					}
				end

				if cap == "test.definition" then
					local name = vim.treesitter.get_node_text(child:field("name")[1], src) or "Unknown"

					local parts = {}
					local cur = child:parent()
					while cur do
						if cur:type() == "class_declaration" then
							parts[#parts + 1] = vim.treesitter.get_node_text(cur:field("name")[1], src)
						end
						cur = cur:parent()
					end

					local inner_classname = vim.iter(parts):rev():join("$")

					local fqn = (pkg and (pkg .. ".") or "") .. inner_classname .. "#" .. name

					return {
						{
							id = fqn,
							name = name,
							path = file_path,
							range = { child:range() },
							type = "test",
						},
					}
				end
			end)
			:flatten()
			:totable()
	end

	local l = build_tree(ts_tree:root())

	return Tree.from_list({
		{
			id = file_path,
			name = file_path:gsub(".*/", ""),
			path = file_path,
			range = { ts_tree:root():range() },
			type = "file",
		},
		l,
	}, function(pos)
		return pos.id
	end)
end

return PositionsDiscoverer
