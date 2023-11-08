local lib = require("neotest.lib")

PositionsDiscoverer = {}

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function PositionsDiscoverer:discover_positions(file_path)
	local query = [[
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

	return lib.treesitter.parse_positions(file_path, query)
end

return PositionsDiscoverer
