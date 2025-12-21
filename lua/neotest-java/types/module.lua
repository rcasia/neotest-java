---@class neotest-java.Module
---@field base_dir neotest-java.Path
---@field name string
local Module = {}
Module.__index = Module

---@param base_dir neotest-java.Path
---@return neotest-java.Module
function Module.new(base_dir)
	local self = setmetatable({}, Module)
	self.base_dir = base_dir
	self.name = base_dir.name()
	return self
end

return Module
