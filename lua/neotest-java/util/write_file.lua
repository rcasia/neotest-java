local File = require("neotest.lib.file")

---@param filepath string
---@param content string
local function write_file(filepath, content)
	-- for os compatibibility
	local compatible_path = filepath:gsub("\\", File.sep):gsub("/", File.sep)

	local file = io.open(compatible_path, "w") or error(string.format("could not write to file %s", compatible_path))
	file:write(content)
	file:close()
end

return write_file
