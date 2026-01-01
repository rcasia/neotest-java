local Path = require("neotest-java.model.path")

---@param path string
---@return string compatible_path
local function compatible_path(path)
	return Path(path).to_string()
end

return compatible_path
