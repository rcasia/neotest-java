local Path = require("plenary.path")
local logger = require("neotest-java.logger")

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

local function replace_plain(s, search, replacement)
	local start_pos, end_pos = string.find(s, search, 1, true)
	if start_pos then
		return s:sub(1, start_pos - 1) .. replacement .. s:sub(end_pos + 1)
	else
		return s -- Return the original string if the search string is not found
	end
end

---@return string[]
function Module:get_module_dependencies()
	if self.base_dir:find("api") then
		return { replace_plain(self.base_dir, "sample-api", "sample-common") }
	end

	if self.base_dir:find("admin") then
		return { replace_plain(self.base_dir, "sample-admin", "sample-common") }
	end
	return {}
end

return Module
