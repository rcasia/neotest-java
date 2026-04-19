local log = require("neotest-java.logger")
local lib = require("neotest.lib")

local RootFinder = {}

local BUILD_AND_WRAPPER_PATTERNS = {
	"pom.xml",
	"settings.gradle",
	"settings.gradle.kts",
	"build.gradle",
	"build.gradle.kts",
	"mvnw",
	"gradlew",
}

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param dir string @Directory to treat as cwd
---@param matcher? fun(pattern: string): fun(dir: string): string | nil
---@return string | nil @Absolute root dir of test suite
function RootFinder.find_root(dir, matcher)
	matcher = matcher or lib.files.match_root_pattern

	-- Priority 1: a directory that has both .git and a build file / wrapper.
	-- This correctly identifies the repo root in multi-module projects where
	-- a closer ancestor may also contain a build file.
	local git_root = matcher(".git")(dir)
	if git_root then
		for _, pattern in ipairs(BUILD_AND_WRAPPER_PATTERNS) do
			if matcher(pattern)(git_root) == git_root then
				log.debug("Found root with .git and " .. pattern .. ": " .. git_root)
				return git_root
			end
		end
	end

	-- Priority 2: nearest build file or wrapper (no .git requirement).
	for _, pattern in ipairs(BUILD_AND_WRAPPER_PATTERNS) do
		local root = matcher(pattern)(dir)
		if root then
			log.debug("Found root: " .. root)
			return root
		end
	end

	-- Priority 3: .git alone.
	if git_root then
		log.debug("Found root: " .. git_root)
		return git_root
	end

	log.debug("No root found for " .. dir .. ".")
	return nil
end

return RootFinder
