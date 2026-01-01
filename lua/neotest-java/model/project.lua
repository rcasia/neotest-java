local Module = require("neotest-java.model.module")

---@class neotest-java.Project
---@field project_filename string
---@field private _modules neotest-java.Module[]
local Project = {}
Project.__index = Project

local modules_from_dirs_and_project_file = function(dirs, project_filename)
	---@type table<neotest-java.Module>
	local modules = {}
	for _, path in ipairs(dirs) do
		if path.to_string():find(project_filename) then
			modules[#modules + 1] = Module.new(path.parent())
		end
	end
	return modules
end

---@param dirs neotest-java.Path[]
---@param project_filename string
---@return neotest-java.Project
function Project.from_dirs_and_project_file(dirs, project_filename)
	local self = setmetatable({}, Project)
	self.project_filename = project_filename
	self._modules = modules_from_dirs_and_project_file(dirs, project_filename)
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
			return filepath.contains(mod.base_dir.to_string())
		end)
		--- @param acc neotest-java.Module | nil
		--- @param mod neotest-java.Module
		:fold(nil, function(acc, mod)
			if not acc or #mod.base_dir.to_string() > #acc.base_dir.to_string() then
				acc = mod
			end
			return acc
		end)
end

return Project
