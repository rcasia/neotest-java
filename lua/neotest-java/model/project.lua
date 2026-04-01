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

local modules_from_dirs_and_project_file = function(dirs, project_filename, build_tool)
	---@type neotest-java.Module[]
	local modules = {}
	local seen_module_paths = {}
	local uses_lua_pattern = project_filename:find("%", 1, true) ~= nil

	for _, path in ipairs(dirs) do
		local filename = path:name()
		local matches_project_file = uses_lua_pattern and filename:find(project_filename) ~= nil
			or filename == project_filename

		local is_gradle_settings_file = GRADLE_SETTINGS_FILENAMES[filename]
		local is_gradle_internal_file = path:contains(GRADLE_INTERNAL_DIR)

		if filename ~= "" and matches_project_file and not is_gradle_settings_file and not is_gradle_internal_file then
			local module_path = path:parent():to_string()
			if not seen_module_paths[module_path] then
				modules[#modules + 1] = Module.new(path:parent(), build_tool)
				seen_module_paths[module_path] = true
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
