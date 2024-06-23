local root_finder = require("neotest-java.core.root_finder")
local CommandBuilder = require("neotest-java.command.junit_command_builder")
local resolve_qualfied_name = require("neotest-java.util.resolve_qualified_name")
local log = require("neotest-java.logger")
local random_port = require("neotest-java.util.random_port")
local build_tools = require("neotest-java.build_tool")
local nio = require("nio")

SpecBuilder = {}

---@param args neotest.RunArgs
---@param project_type string
---@param config neotest-java.ConfigOpts
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function SpecBuilder.build_spec(args, project_type, config)
	local command = CommandBuilder:new(config, project_type)
	local tree = args.tree
	local position = tree:data()
	local root = assert(root_finder.find_root(position.path))
	local absolute_path = position.path

	-- make sure we are in root_dir
	nio.fn.chdir(root)

	-- JUNIT REPORT DIRECTORY
	local reports_dir = "/tmp/neotest-java/" .. vim.fn.strftime("%d%m%y%H%M%S")
	command:reports_dir(reports_dir)

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

	-- DAP STRATEGY
	if args.strategy == "dap" then
		local port = random_port()

		-- COMPILATION STEPS
		local build_tool = build_tools.get(project_type)
		build_tool.prepare_classpath()

		build_tools.compile_sources(project_type)
		build_tools.compile_test_sources(project_type)

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
				report_file = reports_dir .. "/TEST-junit-jupiter.xml",
				terminated_command_event = terminated_command_event,
			},
		}
	end

	-- NORMAL STRATEGY
	log.debug("junit command: ", command:build())
	return {
		command = command:build(),
		cwd = root,
		symbol = position.name,
		context = { report_file = reports_dir .. "/TEST-junit-jupiter.xml" },
	}
end

return SpecBuilder
