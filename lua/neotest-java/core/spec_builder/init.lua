---@module "neotest"

local root_finder = require("neotest-java.core.root_finder")
local CommandBuilder = require("neotest-java.command.junit_command_builder")
local logger = require("neotest-java.logger")
local random_port = require("neotest-java.util.random_port")
local build_tools = require("neotest-java.build_tool")
local nio = require("nio")
local Project = require("neotest-java.types.project")
local ch = require("neotest-java.context_holder")
local find_module_by_filepath = require("neotest-java.util.find_module_by_filepath")
local compilers = require("neotest-java.core.spec_builder.compiler")
local detect_project_type = require("neotest-java.util.detect_project_type")
local Path = require("neotest-java.util.path")
local scan = require("neotest-java.util.dir_scan")

--- @class neotest-java.BuildSpecDependencies
--- @field mkdir fun(dir: neotest-java.Path)
--- @field chdir fun(dir: neotest-java.Path)
--- @field root_getter fun(): neotest-java.Path
--- @field scan fun(base_dir: neotest-java.Path): neotest-java.Path[]
--- @field compile fun(cwd: string, classpath_file_dir: string, compile_mode: string): string
--- @field report_folder_name_gen fun(build_dir: neotest-java.Path): neotest-java.Path
--- @field build_tool_getter fun(project_type: string): neotest-java.BuildTool
--- @field detect_project_type fun(base_dir: neotest-java.Path): string

local SpecBuilder = {}

--- @type neotest-java.BuildSpecDependencies
local DEFAULT_DEPENDENCIES = {
	mkdir = function(dir)
		vim.uv.fs_mkdir(dir.to_string(), 493)
	end,

	chdir = function(dir)
		nio.fn.chdir(dir.to_string())
	end,

	root_getter = function()
		local root = ch.get_context().root
		if root then
			return Path(root)
		end
		root = root_finder.find_root(vim.fn.getcwd())
		if root then
			return Path(root)
		end
		error("Could not find project root")
	end,

	scan = scan,

	compile = function(cwd, classpath_file_dir, compile_mode)
		return compilers.jdtls.compile({
			cwd = cwd,
			classpath_file_dir = classpath_file_dir,
			compile_mode = compile_mode,
		})
	end,
	report_folder_name_gen = function(build_dir)
		return build_dir.append("junit-reports").append(nio.fn.strftime("%d%m%y%H%M%S"))
	end,
	build_tool_getter = function(project_type)
		return build_tools.get(project_type)
	end,
	detect_project_type = function(base_dir)
		return detect_project_type(base_dir)
	end,
}

---@param args neotest.RunArgs
---@param config neotest-java.ConfigOpts
---@param deps neotest-java.BuildSpecDependencies
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function SpecBuilder.build_spec(args, config, deps)
	--- @type neotest-java.BuildSpecDependencies
	deps = vim.tbl_extend("force", DEFAULT_DEPENDENCIES, deps or {})

	if args.strategy == "dap" then
		local ok_dap, _ = pcall(require, "dap")
		assert(ok_dap, "neotest-java requires nvim-dap to run debug tests")
	end

	local tree = args.tree
	local position = tree:data()
	local root = deps.root_getter()
	local project_type = deps.detect_project_type(root)
	--- @type neotest-java.BuildTool
	local build_tool = deps.build_tool_getter(project_type)
	local command = CommandBuilder.new(config.junit_jar)
	local project = assert(
		Project.from_root_dir(root, build_tool.get_project_filename(), deps.scan(root)),
		"project not detected correctly"
	)
	local modules = project:get_modules()

	-- make sure we are in root_dir
	deps.chdir(root)

	-- make sure build directory is created to operate in it
	local build_dir = build_tool.get_build_dirname()

	deps.mkdir(build_dir)
	deps.mkdir(build_dir.parent())

	-- JUNIT REPORT DIRECTORY
	local reports_dir = deps.report_folder_name_gen(build_dir)
	command:reports_dir(reports_dir)

	local module_dirs = vim
		.iter(modules)
		--- @param mod neotest-java.Module
		:map(function(mod)
			return mod.base_dir.to_string()
		end)
		:totable()
	local base_dir = assert(find_module_by_filepath(module_dirs, position.path), "module base_dir not found")
	command:basedir(base_dir)

	command:spring_property_filepaths(build_tool.get_spring_property_filepaths(module_dirs))

	-- TEST SELECTORS
	if position.type == "test" then
		command:add_test_method(position.id)
	else
		for _, child in tree:iter() do
			if child.type == "test" then
				command:add_test_method(child.id)
			end
		end
	end

	-- COMPILATION STEP
	local compile_mode = ch.config().incremental_build and "incremental" or "full"
	local classpath_file_arg = deps.compile(base_dir, build_dir.to_string(), compile_mode)
	command:classpath_file_arg(classpath_file_arg)

	-- DAP STRATEGY
	if args.strategy == "dap" then
		local port = random_port()

		-- PREPARE DEBUG TEST COMMAND
		local junit = command:build_junit(port)
		logger.debug("junit debug command: ", junit.command, " ", table.concat(junit.args, " "))
		local terminated_command_event = build_tools.launch_debug_test(junit.command, junit.args)

		local project_name = vim.fn.fnamemodify(root.to_string(), ":t")
		return {
			strategy = {
				type = "java",
				request = "attach",
				name = ("neotest-java (on port %s)"):format(port),
				host = "localhost",
				port = port,
				projectName = project_name,
			},
			cwd = root.to_string(),
			symbol = position.type == "test" and position.name or nil,
			context = {
				strategy = args.strategy,
				reports_dir = reports_dir,
				terminated_command_event = terminated_command_event,
			},
		}
	end

	-- NORMAL STRATEGY
	logger.info("junit command: ", command:build_to_string())
	return {
		command = command:build_to_string(),
		cwd = root.to_string(),
		symbol = position.name,
		context = { reports_dir = reports_dir },
	}
end

return SpecBuilder
