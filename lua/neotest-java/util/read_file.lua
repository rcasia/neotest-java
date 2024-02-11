local File = require("neotest.lib.file")

---@param path string
local function read_file(path)
	-- for os compatibibility
	local compatible_path = path:gsub("\\", File.sep):gsub("/", File.sep)

	return File.read(compatible_path)
end

return read_file
