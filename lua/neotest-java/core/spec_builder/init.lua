---@module "neotest"

local root_finder = require("neotest-java.core.root_finder")
local CommandBuilder = require("neotest-java.command.junit_command_builder")
local logger = require("neotest-java.logger")
local random_port = require("neotest-java.util.random_port")
local build_tools = require("neotest-java.build_tool")
local nio = require("nio")
local path = require("plenary.path")
local compatible_path = require("neotest-java.util.compatible_path")
local Project = require("neotest-java.types.project")
local ch = require("neotest-java.context_holder")
local find_module_by_filepath = require("neotest-java.util.find_module_by_filepath")
local compilers = require("neotest-java.core.spec_builder.compiler")
local plenary_scan = require("plenary.scandir")
local should_ignore_path = require("neotest-java.util.should_ignore_path")

--- @class neotest-java.BuildSpecDependencies
--- @field mkdir fun(dir: string)
--- @field chdir fun(dir: string)
--- @field root_getter fun(): string
--- @field scan fun(base_dir: string): string[]
--- @field compile fun(cwd: string, classpath_file_dir: string, compile_mode: string): string
--- @field report_folder_name_gen fun(output_dir: string): string
--- @field build_tool_getter fun(project_type: string): neotest-java.BuildTool

local SpecBuilder = {}

--- @type neotest-java.BuildSpecDependencies
local DEFAULT_DEPENDENCIES = {
	mkdir = function(dir)
		vim.uv.fs_mkdir(dir, 493)
	end,

	chdir = function(dir)
		nio.fn.chdir(dir)
	end,

	root_getter = function()
		return ch.get_context().root or root_finder.find_root(vim.fn.getcwd())
	end,

	scan = function(base_dir)
		return plenary_scan.scan_dir(base_dir, {
			search_pattern = function(path, project_file)
				return not should_ignore_path(path) and path:find(project_file)
			end,
			respect_gitignore = false,
		})
	end,

	compile = function(cwd, classpath_file_dir, compile_mode)
		return compilers.jdtls.compile({
			cwd = cwd,
			classpath_file_dir = classpath_file_dir,
			compile_mode = compile_mode,
		})
	end,
	report_folder_name_gen = function(output_dir)
		return string.format("%s/junit-reports/%s", output_dir, nio.fn.strftime("%d%m%y%H%M%S"))
	end,
	build_tool_getter = function(project_type)
		return build_tools.get(project_type)
	end,
}

---@param args neotest.RunArgs
---@param project_type string
---@param config neotest-java.ConfigOpts
---@param deps neotest-java.BuildSpecDependencies
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function SpecBuilder.build_spec(args, project_type, config, deps)
	deps = vim.tbl_extend("force", DEFAULT_DEPENDENCIES, deps or {})

	if args.strategy == "dap" then
		local ok_dap, _ = pcall(require, "dap")
		assert(ok_dap, "neotest-java requires nvim-dap to run debug tests")
	end

	local command = CommandBuilder:new(config, project_type)
	local tree = args.tree
	local position = tree:data()
	local root = assert(deps.root_getter())
	local absolute_path = position.path
	local project = assert(
		Project.from_root_dir(root, build_tools.get(project_type), deps.scan(root)),
		"project not detected correctly"
	)
	local modules = project:get_modules()
	local build_tool = deps.build_tool_getter(project_type)

	-- make sure we are in root_dir
	deps.chdir(root)

	-- make sure outputDir is created to operate in it
	local output_dir = build_tool.get_output_dir()
	local output_dir_parent = compatible_path(path:new(output_dir):parent().filename)

	deps.mkdir(output_dir_parent)
	deps.mkdir(output_dir)
	-- JUNIT REPORT DIRECTORY
	local reports_dir = compatible_path(deps.report_folder_name_gen(output_dir))
	command:reports_dir(compatible_path(reports_dir))

	local module_dirs = vim.iter(modules)
		:map(function(mod)
			return mod.base_dir
		end)
		:totable()
	local base_dir = assert(find_module_by_filepath(module_dirs, position.path), "module base_dir not found")
	command:basedir(base_dir)

	command:spring_property_filepaths(build_tool.get_spring_property_filepaths(module_dirs))

	-- TEST SELECTORS
	if position.type == "test" then
		command:test_reference(position.id, position.name, "test")
	else
		for _, child in tree:iter() do
			if child.type == "test" then
				command:test_reference(child.id, child.name, "test")
			end
		end
	end

	-- COMPILATION STEP
	local compile_mode = ch.config().incremental_build and "incremental" or "full"
	local classpath_file_arg = deps.compile(base_dir, output_dir, compile_mode)
	command:classpath_file_arg(classpath_file_arg)

	-- DAP STRATEGY
	if args.strategy == "dap" then
		local port = random_port()

		-- PREPARE DEBUG TEST COMMAND
		local junit = command:build_junit(port)
		logger.debug("junit debug command: ", junit.command, " ", table.concat(junit.args, " "))
		local terminated_command_event = build_tools.launch_debug_test(junit.command, junit.args)

		local project_name = vim.fn.fnamemodify(root, ":t")
		return {
			strategy = {
				type = "java",
				request = "attach",
				name = ("neotest-java (on port %s)"):format(port),
				host = "localhost",
				port = port,
				projectName = project_name,
			},
			cwd = root,
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
		cwd = root,
		symbol = position.name,
		context = { reports_dir = reports_dir },
	}
end

return SpecBuilder
