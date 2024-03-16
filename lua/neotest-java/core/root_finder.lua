local lib = require("neotest.lib")

RootFinder = {}
---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param buildtools table<neotest-java.BuildTool>
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function RootFinder.find_root(buildtools, dir)
	for _, buildtool in ipairs(buildtools) do
		for _, matcher in ipairs(buildtool.project_files) do
			local root = lib.files.match_root_pattern(matcher)(dir)
			if root then
				return root
			end
		end
	end

	return nil
end

return RootFinder
