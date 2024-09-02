local lib = require("neotest.lib")
local log = require("neotest-java.logger")
local Path = require("plenary.path")

local RootFinder = {}

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function RootFinder.find_root(dir)
	local matchers = {
		"pom.xml",
		"build.gradle",
		"build.gradle.kts",
		".git",
	}

	for _, matcher in ipairs(matchers) do
		local root = lib.files.match_root_pattern(matcher)(dir)
		local parent_dir = Path:new(dir):parent().filename
		local is_parent_root_canditate = lib.files.match_root_pattern(matcher)(parent_dir)

		if root and not is_parent_root_canditate then
			log.debug("Found root: " .. root)
			return root
		end
	end

	log.debug("No root found for " .. dir .. ".")
	return nil
end

return RootFinder
