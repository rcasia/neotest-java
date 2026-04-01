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

local is_project_build_file = function(filename, project_filename, uses_lua_pattern)
	if uses_lua_pattern then
		return filename:find(project_filename) ~= nil
	end

	return filename == project_filename
end

local is_internal_gradle_file = function(path, filename)
	return GRADLE_SETTINGS_FILENAMES[filename] or path:contains(GRADLE_INTERNAL_DIR)
end

local is_candidate_module_path = function(path, project_filename, uses_lua_pattern)
	local filename = path:name()
	if filename == "" then
		return false
	end

	if not is_project_build_file(filename, project_filename, uses_lua_pattern) then
		return false
	end

	if is_internal_gradle_file(path, filename) then
		return false
	end

	return true
end

local modules_from_dirs_and_project_file = function(dirs, project_filename, build_tool)
	local uses_lua_pattern = project_filename:find("%", 1, true) ~= nil

	local result = vim.iter(dirs)
		:filter(function(path)
			return is_candidate_module_path(path, project_filename, uses_lua_pattern)
		end)
		:map(function(path)
			local module_dir = path:parent()
			return {
				module_dir = module_dir,
				module_dir_path = module_dir:to_string(),
			}
		end)
		:fold({ modules = {}, seen_module_directory_paths = {} }, function(acc, candidate)
			if acc.seen_module_directory_paths[candidate.module_dir_path] then
				return acc
			end

			acc.seen_module_directory_paths[candidate.module_dir_path] = true
			acc.modules[#acc.modules + 1] = Module.new(candidate.module_dir, build_tool)
			return acc
		end)

	return result.modules
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
