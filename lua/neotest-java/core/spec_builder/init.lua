---@module "neotest"

local CommandBuilder = require("neotest-java.command.junit_command_builder")
local logger = require("neotest-java.logger")
local random_port = require("neotest-java.util.random_port")
local build_tools = require("neotest-java.build_tool")
local nio = require("nio")
local Project = require("neotest-java.model.project")
local compilers = require("neotest-java.core.spec_builder.compiler")
local detect_project_type = require("neotest-java.util.detect_project_type")
local Path = require("neotest-java.model.path")
local scan = require("neotest-java.util.dir_scan")
local ClasspathProvider = require("neotest-java.core.spec_builder.compiler.classpath_provider")
local client_provider = require("neotest-java.core.spec_builder.compiler.client_provider")
local Binaries = require("neotest-java.command.binaries")

--- @class neotest-java.BuildSpecDependencies
--- @field mkdir fun(dir: neotest-java.Path)
--- @field chdir fun(dir: neotest-java.Path)
--- @field root_getter fun(): neotest-java.Path
--- @field scan fun(base_dir: neotest-java.Path, opts?: { search_patterns?: string[] }): neotest-java.Path[]
--- @field compile fun(cwd: neotest-java.Path, compile_mode: string)
--- @field classpath_provider neotest-java.ClasspathProvider
--- @field report_folder_name_gen fun(module_dir: neotest-java.Path, build_dir: neotest-java.Path): neotest-java.Path
--- @field build_tool_getter fun(project_type: string): neotest-java.BuildTool
--- @field detect_project_type fun(base_dir: neotest-java.Path): string
--- @field binaries neotest-java.LspBinaries

local SpecBuilder = {}

--- @type neotest-java.BuildSpecDependencies
local DEFAULT_DEPENDENCIES = {
	mkdir = function()
		error("should not reach here")
	end,

	chdir = function()
		error("should not reach here")
	end,

	root_getter = function()
		error("should not reach here")
	end,

	scan = scan,

	compile = function(cwd, compile_mode)
		compilers.lsp.compile({
			base_dir = cwd,
			compile_mode = compile_mode,
		})
	end,
	classpath_provider = ClasspathProvider({ client_provider = client_provider }),
	report_folder_name_gen = function(module_dir, build_dir)
		local base = (module_dir and module_dir:append(build_dir:to_string())) or build_dir
		return base:append("junit-reports"):append(nio.fn.strftime("%d%m%y%H%M%S"))
	end,
	build_tool_getter = function(project_type)
		return build_tools.get(project_type)
	end,
	detect_project_type = function(base_dir)
		return detect_project_type(base_dir)
	end,
	binaries = Binaries({ client_provider = client_provider }),
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
	local filepath = Path(position.path)
	local root = deps.root_getter()
	local project_type = deps.detect_project_type(root)
	--- @type neotest-java.BuildTool
	local build_tool = deps.build_tool_getter(project_type)
	local command = CommandBuilder.new(config.junit_jar, config.jvm_args)
	local project = assert(
		Project.from_dirs_and_project_file(deps.scan(root), build_tool.get_project_filename()),
		"project not detected correctly"
	)

	-- make sure we are in root_dir
	deps.chdir(root)

	-- make sure build directory is created to operate in it
	local build_dir = build_tool.get_build_dirname()

	deps.mkdir(build_dir)
	deps.mkdir(build_dir:parent())

	-- JAVA BIN
	command:java_bin(deps.binaries.java(filepath:parent()))

	local module =
		--
		project:is_multimodule()
			--
			and assert(
				project:find_module_by_filepath(filepath),
				"module not found in multimodule project for filepath: " .. filepath:to_string()
			)
		or project:get_modules()[1]

	command:basedir(module.base_dir)

	-- JUNIT REPORT DIRECTORY
	local reports_dir = deps.report_folder_name_gen(module.base_dir, build_dir)
	command:reports_dir(reports_dir)

	command:spring_property_filepaths(build_tool.get_spring_property_filepaths(project:get_module_dirs()))

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
	local compile_mode = config.incremental_build and "incremental" or "full"
	deps.compile(module.base_dir, compile_mode)

	local classpath_file_arg = deps.classpath_provider.get_classpath(
		module.base_dir,
		deps.scan(module.base_dir, { search_patterns = { Path("test/resources$"):to_string() } })
	)
	command:classpath_file_arg(classpath_file_arg)

	-- DAP STRATEGY
	if args.strategy == "dap" then
		local port = random_port()

		-- PREPARE DEBUG TEST COMMAND
		local junit = command:build_junit(port)
		logger.debug("junit debug command: ", junit.command, " ", table.concat(junit.args, " "))
		local terminated_command_event = build_tools.launch_debug_test(junit.command, junit.args, module.base_dir)

		local project_name = vim.fn.fnamemodify(root:to_string(), ":t")
		return {
			strategy = {
				type = "java",
				request = "attach",
				name = ("neotest-java (on port %s)"):format(port),
				host = "localhost",
				port = port,
				projectName = project_name,
			},
			cwd = module.base_dir:to_string(),
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
		cwd = module.base_dir:to_string(),
		symbol = position.name,
		context = { reports_dir = reports_dir },
	}
end

return SpecBuilder
