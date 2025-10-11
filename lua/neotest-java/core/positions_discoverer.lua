local lib = require("neotest.lib")
local resolve_package_name = require("neotest-java.util.resolve_package_name")

local PositionsDiscoverer = {}

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
					return package_name ~= "" and package_name .. "." .. position.name or position.name
				end
				return package_name ~= ""
						--
						and package_name .. "." .. namespace_string .. "$" .. position.name
					or namespace_string .. "$" .. position.name
			end

			return package_name ~= ""
					--
					and package_name .. "." .. namespace_string .. "#" .. position.name
				or namespace_string .. "#" .. position.name
		end,
	})
end

return PositionsDiscoverer
