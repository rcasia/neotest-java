---@class neotest-java.Module
---@field base_dir string
---@field _build_tool neotest-java.BuildTool
local Module = {}
Module.__index = Module

---@param base_dir string
---@param build_tool neotest-java.BuildTool
---@return neotest-java.Module
function Module.new(base_dir, build_tool)
	local self = setmetatable({}, Module)
	self.base_dir = base_dir
	self._build_tool = build_tool
	return self
end

---@return table<string> main_source_classes
function Module:get_sources()
	return self._build_tool.get_sources(self.base_dir)
end

---@return table<string> test_source_classes
function Module:get_test_sources()
	return self._build_tool.get_test_sources(self.base_dir)
end

function Module:get_output_dir()
	return self._build_tool.get_output_dir(self.base_dir)
end

function Module:get_resources()
	return self._build_tool.get_resources(self.base_dir)
end

---@return string
function Module:to_string()
	return "neotest-java.Module: { base_dir = " .. self.base_dir .. " }"
end

function Module:prepare_classpath()
	local output_dir = self:get_output_dir()
	local resources = self:get_resources()
	self._build_tool.prepare_classpath({ output_dir }, resources, self)
end

return Module
