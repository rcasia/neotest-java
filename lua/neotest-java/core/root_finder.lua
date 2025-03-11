local log = require("neotest-java.logger")

local RootFinder = {}

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param dir string @Directory to treat as cwd
---@param matcher fun(pattern: string): fun(dir: string): string | nil
---@return string | nil @Absolute root dir of test suite
function RootFinder.find_root(dir, matcher)
	local patterns = {
		"pom.xml",
		"settings.gradle",
		"settings.gradle.kts",
		".git",
	}

	for _, m in ipairs(patterns) do
		local root = matcher(m)(dir)

		if root then
			log.debug("Found root: " .. root)
			return root
		end
	end

	log.debug("No root found for " .. dir .. ".")
	return nil
end

return RootFinder
