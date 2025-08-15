local LAST_PATH_SEGMENT_REGEX = "([^/\\]+)$"

---@class neotest-java.Module
---@field base_dir string
---@field _build_tool neotest-java.BuildTool
---@field name string
---@field module_dependencies string[]
local Module = {}
Module.__index = Module

---@param base_dir string
---@param build_tool neotest-java.BuildTool
---@return neotest-java.Module
function Module.new(base_dir, build_tool)
	local self = setmetatable({}, Module)
	self.base_dir = base_dir
	self.name = base_dir:match(LAST_PATH_SEGMENT_REGEX) or base_dir
	self._build_tool = build_tool
	return self
end

function Module:get_output_dir()
	return self._build_tool.get_output_dir(self.base_dir)
end

---@return string[]
function Module:get_module_dependencies()
	return self.module_dependencies or {}
end

return Module
