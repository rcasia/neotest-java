local lib = require("neotest.lib")

PositionsDiscoverer = {}

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function PositionsDiscoverer:discover_positions(file_path)
	local query = [[

       ;; Test class
        (class_declaration
          name: (identifier) @namespace.name
        ) @namespace.definition

      ;; @Test and @ParameterizedTest functions
      (method_declaration
        (modifiers
          (marker_annotation
            name: (identifier) @annotation 
              (#any-of? @annotation "Test" "ParameterizedTest")
            )
        )
        name: (identifier) @test.name
      ) @test.definition

    ]]

	return lib.treesitter.parse_positions(file_path, query, { nested_namespaces = true })
end

return PositionsDiscoverer
