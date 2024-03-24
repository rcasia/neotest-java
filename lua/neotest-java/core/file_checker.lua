local File = require("neotest.lib.file")
FileChecker = {
	test_file_patterns = {
		"IT%.java$",
		"Test%.java$",
		"Tests%.java$",
		"Spec%.java$",
		"IntegrationTest%.java$",
		"IntegrationTests%.java$",
	},
	test_file_body = {
		"@Test",
	},
}
local function fileBodyContainsPattern(file_path)
	for _, annotation in ipairs(FileChecker.test_file_body) do
		if string.find(File.read(file_path), annotation) then
			return true
		end
	end
	return false
end

local function fileNameMatchesPattern(file_path)
	for _, pattern in ipairs(FileChecker.test_file_patterns) do
		if string.find(file_path, pattern) then
			return true
		end
	end
	return false
end

---@async
---@param file_path string
---@return boolean
function FileChecker.isTestFile(file_path)
	return fileNameMatchesPattern(file_path) or fileBodyContainsPattern(file_path)
end

return FileChecker
