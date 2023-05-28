local lib = require("neotest.lib")

SpecBuilder = {}
---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function SpecBuilder.findRoot(dir)
  return lib.files.match_root_pattern("pom.xml")(dir)
end

return SpecBuilder
