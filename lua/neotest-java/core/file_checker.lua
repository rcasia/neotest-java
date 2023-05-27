FileChecker = {}

---@async
---@param file_path string
---@return boolean
function FileChecker.isTestFile(file_path)
	return file_path:match("Test%.java$") ~= nil
end

return FileChecker
