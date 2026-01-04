local JAVA_TEST_FILE_REGEXES = require("neotest-java.model.patterns").JAVA_TEST_FILE_REGEXES
local root_finder = require("neotest-java.core.root_finder")
local ch = require("neotest-java.context_holder")
local Path = require("neotest-java.model.path")

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

	--- @type neotest-java.Path
	local my_path = Path(file_path)
	local base_dir = deps.root_getter()

	local relative_path = my_path:make_relative(base_dir)
	if relative_path:contains("main") then
		return false
	end

	for _, re in ipairs(JAVA_TEST_FILE_REGEXES) do
		local name_without_extension = my_path:name():gsub("%.java$", "")
		if name_without_extension:match(re) then
			return true
		end
	end
	return false
end

return FileChecker
