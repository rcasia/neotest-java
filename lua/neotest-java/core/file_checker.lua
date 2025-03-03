local JAVA_TEST_FILE_PATTERNS = require("neotest-java.types.patterns").JAVA_TEST_FILE_PATTERNS

local FileChecker = {}

---@async
---@param file_path string
---@return boolean
function FileChecker.is_test_file(file_path)
	if string.find(file_path, "main/") then
		return false
	end
	for _, pattern in ipairs(JAVA_TEST_FILE_PATTERNS) do
		if string.find(file_path, pattern) then
			return true
		end
	end
	return false
end

return FileChecker
