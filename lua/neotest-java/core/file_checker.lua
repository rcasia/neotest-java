local File = require("neotest.lib.file")
local FileChecker = {
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
	test_base_file_path = {
		"src/test",
	},
}
local function fileNameMatchesPattern(file_path)
	for _, pattern in ipairs(FileChecker.test_file_patterns) do
		if string.find(file_path, pattern) then
			return true
		end
	end
	return false
end

local function packagePathMatchesPattern(file_path)
	for _, path in ipairs(FileChecker.test_base_file_path) do
		if string.find(file_path, path) then
			return true
		end
	end
	return false
end

local function fileBodyContainsPattern(file_path)
	for _, annotation in ipairs(FileChecker.test_file_body) do
		if string.find(File.read(file_path), annotation) then
			return true
		end
	end
	return false
end

---@async
---@param file_path string
---@return boolean
function FileChecker.isTestFile(file_path)
	return fileNameMatchesPattern(file_path)
		or (packagePathMatchesPattern(file_path) and fileBodyContainsPattern(file_path))
end

return FileChecker
