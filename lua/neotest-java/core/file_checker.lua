FileChecker = {
	test_file_patterns = {
		"IT%.java$",
		"Test%.java$",
		"IntegrationTest%.java$",
		"IntegrationTests%.java$",
	},
}

---@async
---@param file_path string
---@return boolean
function FileChecker.isTestFile(file_path)
	for _, pattern in ipairs(FileChecker.test_file_patterns) do
		if string.find(file_path, pattern) then
			return true
		end
	end

	return false
end

return FileChecker
