local Path = require("plenary.path")

---@param path string
---@return string compatible_path
local function compatible_path(path)
	return Path:new(path).filename
end

return compatible_path
