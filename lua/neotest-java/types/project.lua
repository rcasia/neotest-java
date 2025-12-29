local Module = require("neotest-java.types.module")
local logger = require("neotest-java.logger")
local Path = require("neotest-java.util.path")

---@class neotest-java.Project
---@field root_dir neotest-java.Path
---@field project_filename string
---@field dirs neotest-java.Path[]
local Project = {}
Project.__index = Project

---@param root_dir neotest-java.Path
---@param project_filename string
---@param dirs neotest-java.Path[]
---@return neotest-java.Project
function Project.from_root_dir(root_dir, project_filename, dirs)
	local self = setmetatable({}, Project)
	self.root_dir = root_dir
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
	logger.debug("Root directory: ", self.root_dir.to_string())

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
function Project:find_module_by_filepath(filepath)
	---@type string[]
	local module_dirs = vim.iter(self:get_modules())
		:map(function(mod)
			return mod.base_dir.to_string()
		end)
		:totable()

	--- @type neotest-java.Path[]
	local _module_dirs = vim.iter(module_dirs):map(Path):totable()
	--- @type neotest-java.Path
	local _filepath = Path(filepath.to_string())

	logger.debug("module_dirs", module_dirs)
	logger.debug("filepath", filepath)
	if not filepath or filepath == "" then
		return nil
	end

	--- @type neotest-java.Path[]
	local matches = {}

	for _, module_dir in ipairs(_module_dirs) do
		logger.debug(
			"Checking if module_dir '"
				.. module_dir.to_string()
				.. "' is contained in filepath '"
				.. _filepath.to_string()
				.. "'"
		)
		if _filepath.contains(module_dir.to_string()) then
			table.insert(matches, module_dir)
		end
	end

	logger.debug(
		"Found matches:",
		vim.tbl_map(function(path)
			return path.to_string()
		end, matches)
	)

	-- Select the longest match from all the matches
	--- @type neotest-java.Path | nil
	local longest_match = nil
	for _, path in ipairs(matches) do
		if not longest_match or #path.to_string() > #longest_match.to_string() then
			longest_match = path
		end
	end

	local module_dir = longest_match and longest_match.to_string()
	if not module_dir then
		return nil
	end

	for _, mod in ipairs(self:get_modules()) do
		if mod.base_dir == Path(module_dir) then
			return mod
		end
	end

	return nil
end

return Project
