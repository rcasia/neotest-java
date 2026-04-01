local Module = require("neotest-java.model.module")

---@class neotest-java.Project
---@field project_filename string
---@field private _modules neotest-java.Module[]
---@field private _build_tool neotest-java.BuildTool
local Project = {}
Project.__index = Project

local GRADLE_INTERNAL_DIR = ".gradle"

local is_gradle_settings_file = function(path)
	local name = path:name()
	return name == "settings.gradle" or name == "settings.gradle.kts"
end

local modules_from_dirs_and_project_file = function(dirs, project_filename, build_tool)
	---@type table<neotest-java.Module>
	local modules = {}
	local seen = {}
	for _, path in ipairs(dirs) do
		local path_str = path:to_string()
		local module_dir = path:parent()
		local module_dir_str = module_dir:to_string()
		if
			path_str:find(project_filename)
			and not is_gradle_settings_file(path)
			and not path:contains(GRADLE_INTERNAL_DIR)
			and not seen[module_dir_str]
		then
			modules[#modules + 1] = Module.new(module_dir, build_tool)
			seen[module_dir_str] = true
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
