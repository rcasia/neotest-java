local CommandBuilder = require("neotest-java.command.junit_command_builder")
local resolve_qualfied_name = require("neotest-java.util.resolve_qualified_name")
local log = require("neotest-java.logger")
local random_port = require("neotest-java.util.random_port")
local build_tools = require("neotest-java.build_tool")
local nio = require("nio")
local path = require("plenary.path")
local compatible_path = require("neotest-java.util.compatible_path")
local Project = require("neotest-java.types.project")
local Compiler = require("neotest-java.build_tool.compiler")
local ch = require("neotest-java.context_holder")

local SpecBuilder = {}

---@param args neotest.RunArgs
---@param project_type string
---@param config neotest-java.ConfigOpts
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function SpecBuilder.build_spec(args, project_type, config)
	local command = CommandBuilder:new(config, project_type)
	local tree = args.tree
	local position = tree:data()
	local root = assert(ch:get_context().root)
	local absolute_path = position.path
	local project = assert(Project.from_root_dir(root), "project not detected correctly")

	-- make sure we are in root_dir
	nio.fn.chdir(root)

	-- make sure outputDir is created to operate in it
	local output_dir = build_tools.get(project_type).get_output_dir()
	local output_dir_parent = path:new(output_dir):parent().filename

	vim.uv.fs_mkdir(output_dir_parent, 493)
	vim.uv.fs_mkdir(output_dir, 493)

	-- JUNIT REPORT DIRECTORY
	local reports_dir = string.format("%s/junit-reports/%s", output_dir, nio.fn.strftime("%d%m%y%H%M%S"))
	command:reports_dir(compatible_path(reports_dir))
	command:basedir(project:find_module_by_filepath(position.path).base_dir)

	-- TEST SELECTORS
	if position.type == "dir" then
		for _, child in tree:iter() do
			if child.type == "file" then
				command:test_reference(resolve_qualfied_name(child.path), child.name, "file")
			end
		end
	elseif position.type == "namespace" then
		for _, child in tree:iter() do
			if child.type == "test" then
				command:test_reference(resolve_qualfied_name(child.path), child.name, "test")
			end
		end
	elseif position.type == "file" then
		command:test_reference(resolve_qualfied_name(absolute_path), position.name, "file")
	elseif position.type == "test" then
		-- note: parameterized tests are not being discovered by the junit standalone, so we run tests per file
		command:test_reference(resolve_qualfied_name(absolute_path), position.name, "file")
	end

	-- COMPILATION STEPS
	for _, mod in ipairs(project:get_modules()) do
		Compiler.compile_sources(mod)
		Compiler.compile_test_sources(mod)
	end

	-- DAP STRATEGY
	if args.strategy == "dap" then
		local port = random_port()

		-- PREPARE DEBUG TEST COMMAND
		local junit = command:build_junit(port)
		log.debug("junit debug command: ", junit.command, " ", table.concat(junit.args, " "))
		local terminated_command_event = build_tools.launch_debug_test(junit.command, junit.args)

		return {
			strategy = {
				type = "java",
				request = "attach",
				name = "neotest-java debug test",
				port = port,
			},
			cwd = root,
			symbol = position.name,
			context = {
				strategy = args.strategy,
				reports_dir = reports_dir,
				terminated_command_event = terminated_command_event,
			},
		}
	end

	-- NORMAL STRATEGY
	log.info("junit command: ", command:build_to_string())
	return {
		command = command:build_to_string(),
		cwd = root,
		symbol = position.name,
		context = { reports_dir = reports_dir },
	}
end

return SpecBuilder
