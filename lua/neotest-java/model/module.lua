---@class neotest-java.Module
---@field base_dir neotest-java.Path
---@field name string
local Module = {}
Module.__index = Module

---@param base_dir neotest-java.Path
---@param build_tool neotest-java.BuildTool
---@return neotest-java.Module
function Module.new(base_dir, build_tool)
	local self = setmetatable({}, Module)
	self.base_dir = base_dir
	self.name = build_tool and build_tool.get_artifact_id(base_dir) or base_dir:name()
	return self
end

return Module
