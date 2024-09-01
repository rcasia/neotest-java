local build_tools = require("neotest-java.build_tool")
local detect_project_type = require("neotest-java.util.detect_project_type")
local Module = require("neotest-java.types.module")
local scan = require("plenary.scandir")
local Path = require("plenary.path")
local fun = require("fun")
local iter = fun.iter
local totable = fun.totable

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
	-- TODO: replace with build_tool.get_project_filename()
	local project_file = "pom.xml"

	local dirs = scan.scan_dir(self.root_dir, { search_pattern = project_file })

	---@type table<neotest-java.Module>
	local modules = {}
	for _, dir in ipairs(dirs) do
		local base_dir = Path:new(dir):parent().filename
		modules[#modules + 1] = Module.new(base_dir, self.build_tool)
		print(vim.inspect(modules[#modules].base_dir))
		print(vim.inspect(modules[#modules]:get_output_dir()))
	end

	return modules
end

function Project:get_output_dirs()
	return totable(iter(self:get_modules())
		--
		:map(function(mod)
			return mod:get_output_dir()
		end))
end

function Project:prepare_classpath()
	local output_dirs = self:get_output_dirs()
	self.build_tool.prepare_classpath(output_dirs)
end

return Project
