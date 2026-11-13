---@module "neotest"

local CommandBuilder = require("neotest-java.command.junit_command_builder")
local logger = require("neotest-java.logger")
local random_port = require("neotest-java.util.random_port")
local Project = require("neotest-java.model.project")
local Path = require("neotest-java.model.path")

--- @class neotest-java.BuildSpecDependencies
--- @field mkdir fun(dir: neotest-java.Path)
--- @field scan fun(base_dir: neotest-java.Path, opts?: { search_patterns?: string[] }): neotest-java.Path[]
--- @field compile fun(cwd: neotest-java.Path, compile_mode: string): boolean? nil is accepted for legacy synchronous compilers; false is failure.
--- @field classpath_provider neotest-java.ClasspathProvider
--- @field report_folder_name_gen fun(module_dir: neotest-java.Path, build_dir: neotest-java.Path): neotest-java.Path
--- @field build_tool_getter fun(project_type: string): neotest-java.BuildTool
--- @field detect_project_type fun(base_dir: neotest-java.Path): string
--- @field binaries neotest-java.LspBinaries
--- @field launch_debug_test fun(command: string, args: string[], cwd: neotest-java.Path, opts?: table): neotest-java.DebugProcess
--- @field cleanup_reports? fun(dir: neotest-java.Path)
--- @field root_finder? { find_root: fun(dir: string): string | nil }

--- @class neotest-java.SpecBuilder
--- @field build_spec fun(args: neotest.RunArgs, config: neotest-java.ConfigOpts): nil | neotest.RunSpec | neotest.RunSpec[]

--- @param deps neotest-java.BuildSpecDependencies
--- @return neotest-java.SpecBuilder
local SpecBuilder = function(deps)
	--- @type neotest-java.BuildSpecDependencies
	deps = deps or {}
	deps.root_finder = deps.root_finder or require("neotest-java.core.root_finder")

	return {
		---@param args neotest.RunArgs
		---@param config neotest-java.ConfigOpts
		---@return nil | neotest.RunSpec | neotest.RunSpec[]
		build_spec = function(args, config)
			if args.strategy == "dap" then
				local ok_dap, dap = pcall(require, "dap")
				assert(ok_dap, "neotest-java requires nvim-dap to run debug tests")
				assert(
					dap.adapters and dap.adapters.java,
					"Java DAP adapter is unavailable; load the Java Debug bundle in JDTLS and call jdtls.setup_dap()"
				)
			end

			local tree = args.tree
			local position = tree:data()
			local filepath = Path(position.path)

			local root_str = args.tree:root():data().path
			local real_root_str = deps.root_finder.find_root(root_str)
			local root = Path(real_root_str or root_str)

			local project_type = deps.detect_project_type(root)

			--- @type neotest-java.BuildTool
			local build_tool = deps.build_tool_getter(project_type)
			local command = CommandBuilder.new()
				:junit_jar(config.junit_jar)
				:jvm_args(config.jvm_args)
				:test_classname_patterns(config.test_classname_patterns)
			local project = assert(
				Project.from_dirs_and_project_file(deps.scan(root), build_tool.get_project_filename(), build_tool),
				"project not detected correctly"
			)

			local module =
				--
				project:is_multimodule()
					--
					and assert(
						project:find_module_by_filepath(filepath),
						"module not found in multimodule project for filepath: " .. filepath:to_string()
					)
				or project:get_modules()[1]

			-- make sure build directory is created to operate in it
			local build_dir = build_tool.get_build_dirname(module.base_dir)

			deps.mkdir(build_dir)
			deps.mkdir(build_dir:parent())

			-- JAVA BIN
			-- Use module.base_dir (not filepath:parent()) so that the URI passed to
			-- jdtls always points to a directory that belongs to a known project.
			-- When position.type == "dir" and the position is the module root,
			-- filepath:parent() would resolve to the repo root, which jdtls does
			-- not own as a project and rejects with -32001.
			command:java_bin(deps.binaries.java(module.base_dir))

			command:basedir(module.base_dir)

			command:spring_property_filepaths(build_tool.get_spring_property_filepaths(project:get_module_dirs()))

			-- TEST SELECTORS
			command:add_test_references_from_tree(tree)

			-- COMPILATION STEP
			local compile_mode = config.incremental_build and "incremental" or "full"
			local compiled, compile_result = pcall(deps.compile, module.base_dir, compile_mode)
			assert(
				compiled and compile_result ~= false,
				"Java compilation failed for " .. tostring(module.base_dir) .. ": " .. tostring(compile_result)
			)

			local classpath_file_arg = deps.classpath_provider.get_classpath(
				module.base_dir,
				deps.scan(module.base_dir, { search_patterns = { Path("test/resources$"):to_string() } })
			)
			command:classpath_file_arg(classpath_file_arg)

			-- Reserve reports only after compilation/classpath succeed.
			local reports_dir = deps.report_folder_name_gen(module.base_dir, build_dir)
			command:reports_dir(reports_dir)
			local function cleanup_reports()
				if deps.cleanup_reports then
					deps.cleanup_reports(reports_dir)
				end
			end

			-- DAP STRATEGY
			if args.strategy == "dap" then
				local port = random_port()

				-- PREPARE DEBUG TEST COMMAND
				command:port(port)
				local junit = command:build_to_table()
				logger.debug("junit debug command: ", junit.command, " ", table.concat(junit.args, " "))
				local launched, process = pcall(deps.launch_debug_test, junit.command, junit.args, module.base_dir, {
					startup_timeout_ms = config.debug_startup_timeout_ms,
					exit_timeout_ms = config.debug_exit_timeout_ms,
					shutdown_timeout_ms = config.debug_shutdown_timeout_ms,
					on_failure = cleanup_reports,
				})
				if not launched then
					cleanup_reports()
					error(process)
				end

				local project_name = module.name
				return {
					strategy = {
						type = "java",
						request = "attach",
						name = ("neotest-java (on port %s)"):format(port),
						host = "localhost",
						port = port,
						projectName = project_name,
						before = function(cfg)
							process.claim()
							return cfg
						end,
						after = function(reason)
							if reason then
								process.stop(reason)
							end
							local state = process.wait_exit()
							if state.error or state.cancelled or not state.exited then
								error(state.error or "Java test process did not exit")
							end
						end,
					},
					cwd = module.base_dir:to_string(),
					symbol = position.type == "test" and position.name or nil,
					context = {
						strategy = args.strategy,
						reports_dir = reports_dir,
						terminated_command_event = process,
						process = process,
						cleanup_reports = deps.cleanup_reports and cleanup_reports or nil,
					},
				}
			end

			-- NORMAL STRATEGY
			local command_array = command:build_to_array()
			logger.info("junit command: ", vim.inspect(command_array))
			return {
				command = command_array,
				cwd = module.base_dir:to_string(),
				symbol = position.name,
				context = {
					reports_dir = reports_dir,
					cleanup_reports = deps.cleanup_reports and cleanup_reports or nil,
				},
			}
		end,
	}
end

return SpecBuilder
