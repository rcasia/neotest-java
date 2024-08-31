local File = require("neotest.lib.file")

---@param filepath string
---@param content string
local function write_file(filepath, content)
	-- for os compatibibility
	local compatible_path = filepath:gsub("\\", File.sep):gsub("/", File.sep)

	return File.write(compatible_path, content)
end

return write_file
