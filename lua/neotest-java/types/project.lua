local Module = require("neotest-java.types.module")
local logger = require("neotest-java.logger")

---@class neotest-java.Project
---@field root_dir neotest-java.Path
---@field project_filename string
---@field build_tool neotest-java.BuildTool
---@field dirs neotest-java.Path[]
local Project = {}
Project.__index = Project

---@param root_dir neotest-java.Path
---@param build_tool neotest-java.BuildTool
---@param dirs neotest-java.Path[]
---@return neotest-java.Project
function Project.from_root_dir(root_dir, build_tool, dirs)
	local self = setmetatable({}, Project)
	self.root_dir = root_dir
	self.build_tool = build_tool
	self.project_filename = self.build_tool.get_project_filename()
	self.dirs = dirs
	return self
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
			modules[#modules + 1] = Module.new(path.parent(), self.build_tool)
		end
	end

	local base_dirs = {}
	for _, mod in ipairs(modules) do
		base_dirs[#base_dirs + 1] = mod.base_dir
	end
	logger.debug("modules: ", base_dirs)

	return modules
end

return Project
