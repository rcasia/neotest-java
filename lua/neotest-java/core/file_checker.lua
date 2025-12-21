local JAVA_TEST_FILE_PATTERNS = require("neotest-java.types.patterns").JAVA_TEST_FILE_PATTERNS
local root_finder = require("neotest-java.core.root_finder")
local ch = require("neotest-java.context_holder")
local Path = require("neotest-java.util.path")

local FileChecker = {}

--- @class neotest-java.FileCheckerDependencies
--- @field root_getter fun(): neotest-java.Path

--- @type neotest-java.FileCheckerDependencies
local DEFAULT_DEPENDENCIES = {
	root_getter = function()
		local root = ch.get_context().root
		if root then
			return Path(root)
		end
		root = root_finder.find_root(vim.fn.getcwd())
		if root then
			return Path(root)
		end
		error("Could not find project root")
	end,
}

---@async
---@param file_path string
---@param dependencies? neotest-java.FileCheckerDependencies
---@return boolean
function FileChecker.is_test_file(file_path, dependencies)
	local deps = vim.tbl_extend("force", DEFAULT_DEPENDENCIES, dependencies or {})
	local my_path = Path(file_path)
	local base_dir = deps.root_getter()

	local relative_path = my_path.make_relative(base_dir)
	if relative_path.contains("main") then
		return false
	end
	for _, pattern in ipairs(JAVA_TEST_FILE_PATTERNS) do
		if string.find(relative_path.to_string(), pattern) then
			return true
		end
	end
	return false
end

return FileChecker
