local Module = require("neotest-java.types.module")
local logger = require("neotest-java.logger")
local Path = require("neotest-java.util.path")

---@class neotest-java.Project
---@field project_filename string
---@field dirs neotest-java.Path[]
local Project = {}
Project.__index = Project

---@param dirs neotest-java.Path[]
---@param project_filename string
---@return neotest-java.Project
function Project.from_dirs_and_project_file(dirs, project_filename)
	local self = setmetatable({}, Project)
	self.project_filename = project_filename
	self.dirs = dirs
	return self
end

--- @return boolean
function Project:is_multimodule()
	return #self:get_modules() > 1
end

---@return neotest-java.Module[]
function Project:get_modules()
	logger.debug("Searching for project files: ", self.project_filename)

	assert(self.dirs and #self.dirs > 0, "should find at least 1 module in root: " .. tostring(self.root_dir))

	logger.debug("Found project directories: ", self.dirs)

	---@type table<neotest-java.Module>
	local modules = {}
	for _, path in ipairs(self.dirs) do
		if path.to_string():find(self.project_filename) then
			modules[#modules + 1] = Module.new(path.parent())
		end
	end

	local base_dirs = {}
	for _, mod in ipairs(modules) do
		base_dirs[#base_dirs + 1] = mod.base_dir
	end
	logger.debug("modules: ", base_dirs)

	return modules
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
