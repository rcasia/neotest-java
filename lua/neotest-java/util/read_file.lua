local File = require("neotest.lib.file")

---@param path neotest-java.Path
---@return string content
local function read_file(path)
	return File.read(path.to_string())
end

return read_file
