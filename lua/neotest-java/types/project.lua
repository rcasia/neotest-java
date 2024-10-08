local build_tools = require("neotest-java.build_tool")
local detect_project_type = require("neotest-java.util.detect_project_type")
local Module = require("neotest-java.types.module")
local scan = require("plenary.scandir")
local logger = require("neotest-java.logger")
local should_ignore_path = require("neotest-java.util.should_ignore_path")
local compatible_path = require("neotest-java.util.compatible_path")
local Path = require("plenary.path")

---@class neotest-java.Project
---@field root_dir string
---@field build_tool neotest-java.BuildTool
local Project = {}
Project.__index = Project

---@param root_dir string
---@return neotest-java.Project
function Project.from_root_dir(root_dir)
	local self = setmetatable({}, Project)
	self.root_dir = root_dir
	self.build_tool = build_tools.get(detect_project_type(root_dir))
	return self
end

---@return neotest-java.Module[]
function Project:get_modules()
	local project_file = self.build_tool.get_project_filename()
	logger.debug("Searching for project files: ", project_file)
	logger.debug("Root directory: ", self.root_dir)

	-- NOTE: flag respect_gitignore does not work with "build.gradle"
	local dirs = scan.scan_dir(self.root_dir, {
		search_pattern = function(path)
			return not should_ignore_path(path) and path:find(self.build_tool.get_project_filename())
		end,
		respect_gitignore = false,
	})

	assert(dirs and #dirs > 0, "should find at least 1 module")

	logger.debug("Found project directories: ", dirs)

	---@type table<neotest-java.Module>
	local modules = {}
	for _, dir in ipairs(dirs) do
		local base_dir = compatible_path(Path:new(dir):parent().filename)
		local mod = Module.new(base_dir, self.build_tool)
		modules[#modules + 1] = mod
	end

	local base_dirs = {}
	for _, mod in ipairs(modules) do
		base_dirs[#base_dirs + 1] = mod.base_dir
	end
	logger.debug("modules: ", base_dirs)

	return modules
end

return Project
