local Module = require("neotest-java.model.module")

---@class neotest-java.Project
---@field project_filename string
---@field private _modules neotest-java.Module[]
---@field private _build_tool neotest-java.BuildTool
local Project = {}
Project.__index = Project

local GRADLE_INTERNAL_DIR = ".gradle"
local GRADLE_SETTINGS_FILENAMES = {
	["settings.gradle"] = true,
	["settings.gradle.kts"] = true,
}

---@class neotest-java.ModuleDiscoveryPolicy
---@field project_filename string
---@field uses_lua_pattern boolean
local ModuleDiscoveryPolicy = {}
ModuleDiscoveryPolicy.__index = ModuleDiscoveryPolicy

---@param project_filename string
---@return neotest-java.ModuleDiscoveryPolicy
function ModuleDiscoveryPolicy.new(project_filename)
	return setmetatable({
		project_filename = project_filename,
		uses_lua_pattern = project_filename:find("%", 1, true) ~= nil,
	}, ModuleDiscoveryPolicy)
end

---@param filename string
---@return boolean
function ModuleDiscoveryPolicy:matches_project_build_file(filename)
	if self.uses_lua_pattern then
		return filename:find(self.project_filename) ~= nil
	end
	return filename == self.project_filename
end

---@param path neotest-java.Path
---@return boolean
function ModuleDiscoveryPolicy:is_module_build_file(path)
	local filename = path:name()
	if filename == "" then
		return false
	end

	return self:matches_project_build_file(filename)
		and not GRADLE_SETTINGS_FILENAMES[filename]
		and not path:contains(GRADLE_INTERNAL_DIR)
end

local modules_from_dirs_and_project_file = function(dirs, project_filename, build_tool)
	---@type table<neotest-java.Module>
	local modules = {}
	local seen_module_dirs = {}
	local discovery_policy = ModuleDiscoveryPolicy.new(project_filename)

	for _, path in ipairs(dirs) do
		if discovery_policy:is_module_build_file(path) then
			local module_dir = path:parent()
			local module_dir_key = module_dir:to_string()
			if not seen_module_dirs[module_dir_key] then
				modules[#modules + 1] = Module.new(module_dir, build_tool)
				seen_module_dirs[module_dir_key] = true
			end
		end
	end
	return modules
end

---@param dirs neotest-java.Path[]
---@param project_filename string
---@param build_tool neotest-java.BuildTool
---@return neotest-java.Project
function Project.from_dirs_and_project_file(dirs, project_filename, build_tool)
	local self = setmetatable({}, Project)
	self.project_filename = project_filename
	self._build_tool = build_tool
	self._modules = modules_from_dirs_and_project_file(dirs, project_filename, build_tool)
	return self
end

--- @return boolean
function Project:is_multimodule()
	return #self:get_modules() > 1
end

---@return neotest-java.Module[]
function Project:get_modules()
	return self._modules
end

--- @return neotest-java.Path[]
function Project:get_module_dirs()
	return vim
		.iter(self:get_modules())
		--- @param mod neotest-java.Module
		:map(function(mod)
			return mod.base_dir
		end)
		:totable()
end

--- @param filepath neotest-java.Path
--- @return neotest-java.Module | nil
function Project:find_module_by_filepath(filepath)
	return vim
		.iter(self:get_modules())
		---@param mod neotest-java.Module
		:filter(function(mod)
			return filepath:contains(mod.base_dir:to_string())
		end)
		--- @param acc neotest-java.Module | nil
		--- @param mod neotest-java.Module
		:fold(nil, function(acc, mod)
			if not acc or #mod.base_dir:to_string() > #acc.base_dir:to_string() then
				acc = mod
			end
			return acc
		end)
end

return Project
