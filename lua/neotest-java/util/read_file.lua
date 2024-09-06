local File = require("neotest.lib.file")
local compatible_path = require("neotest-java.util.compatible_path")

---@param path string
local function read_file(path)
	return File.read(compatible_path(path))
end

return read_file
