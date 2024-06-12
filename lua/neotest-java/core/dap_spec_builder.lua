local root_finder = require("neotest-java.core.root_finder")
local CommandBuilder = require("neotest-java.command.junit_command_builder")
local resolve_qualfied_name = require("neotest-java.util.resolve_qualified_name")
local binaries = require("neotest-java.command.binaries")
local build_tools = require("neotest-java.build_tool")
local nio = require("nio")
local Job = require("plenary.job")
local run = require("neotest-java.command.run")
local log = require("neotest-java.logger")

SpecBuilder = {}

local random_port = function(start_port, end_port)
	start_port = start_port or 5005
	end_port = end_port or 65535

	local function is_port_in_use(port)
		local handle = assert(io.popen("netstat -an | grep ':" .. port .. "'"))
		local result = handle:read("*a")
		handle:close()
		return result ~= ""
	end

	for port = start_port, end_port do
		if not is_port_in_use(port) then
			return port
		end
	end

	error(("No free port found in the specified range [%s - %s]"):format(start_port, end_port))
end

local compile_sources = function(sources, output_dir, dependencies_classpath)
	local compilation_errors = {}
	local status_code = 0
	local source_compilation_command_exited = nio.control.event()
	local source_compilation_args = {
		"-Xlint:none",
		"-d",
		output_dir .. "/classes",
		"-cp",
		dependencies_classpath,
	}
	for _, source in ipairs(sources) do
		table.insert(source_compilation_args, source)
	end
	Job:new({
		command = binaries.javac(),
		args = source_compilation_args,
		on_stderr = function(_, data)
			table.insert(compilation_errors, data)
		end,
		on_exit = function(_, code)
			status_code = code
			if code == 0 then
				source_compilation_command_exited.set()
			else
				source_compilation_command_exited.set()
				vim.notify("Error compiling sources", "error")
				error("Error compiling sources: " .. table.concat(compilation_errors, "\n"))
			end
		end,
	}):start()
	source_compilation_command_exited.wait()
	assert(status_code == 0, "Error compiling sources")
end

local compile_test_sources = function(build_tool)
	local compilation_errors = {}
	local status_code = 0

	local test_compilation_command_exited = nio.control.event()
	local test_sources_compilation_args = {
		"-Xlint:none",
		"-d",
		build_tool.get_output_dir() .. "/classes",
		"-cp",
		build_tool.get_dependencies_classpath() .. ":" .. build_tool.get_output_dir() .. "/classes",
	}
	for _, source in ipairs(build_tool.get_test_sources()) do
		table.insert(test_sources_compilation_args, source)
	end

	Job:new({
		command = binaries.javac(),
		args = test_sources_compilation_args,
		on_stderr = function(_, data)
			table.insert(compilation_errors, data)
		end,
		on_exit = function(_, code)
			status_code = code
			test_compilation_command_exited.set()
			if code == 0 then
			-- do nothing
			else
				vim.notify("Error compiling test sources", "error")
				error("Error compiling test sources: " .. table.concat(compilation_errors, "\n"))
			end
		end,
	}):start()
	test_compilation_command_exited.wait()
	assert(status_code == 0, "Error compiling test sources")
end

local run_debug_test = function(command, args, log_file)
	log.trace("run_debug_test function")

	local test_command_started_listening = nio.control.event()
	local terminated_command_event = nio.control.event()

	local file, err = io.open(log_file, "w")
	assert(file and not err, err)

	local stderr = {}
	local job = Job:new({
		command = command,
		args = args,
		on_stderr = function(_, data)
			stderr[#stderr + 1] = data
		end,
		on_stdout = function(err, data)
			file:write(data .. "\n")

			if string.find(data, "Listening") then
				test_command_started_listening.set()
			end
		end,
		on_exit = function(_, code)
			file:close()
			terminated_command_event.set()

			log.debug("command exited with code: ", code)
			if code ~= 0 then
				log.error("command exited with code: ", code)
				log.error("stderr: ", table.concat(stderr, "\n"))
			end
		end,
	})
	log.debug("starting job with command: ", command, " ", table.concat(args, " "))
	job:start()
	test_command_started_listening.wait()

	return terminated_command_event
end

---@param args neotest.RunArgs
---@param project_type string
---@param config table
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function SpecBuilder.build_spec(args, project_type, config)
	assert(args.strategy == "dap", "dap spec builder only supports dap strategy")

	log.info("building dap spec")

	local command = CommandBuilder:new(config, project_type)
	local position = args.tree:data()
	local absolute_path = position.path
	local root = root_finder.find_root(absolute_path)
	local port = random_port()
	local log_file = "/tmp/neotest-java/test.log"

	-- JUNIT REPORT
	local reports_dir = "/tmp/neotest-java/" .. vim.fn.strftime("%d%m%y%H%M%S")
	command:reports_dir(reports_dir)

	-- TEST SELECTORS
	if position.type == "dir" then
		for _, child in args.tree:iter() do
			if child.type == "file" then
				command:test_reference(resolve_qualfied_name(child.path), child.name, "file")
			end
		end
	elseif position.type == "namespace" then
		for _, child in args.tree:iter() do
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
	local build_tool = build_tools.get(project_type)
	build_tool.write_classpath(build_tool.get_output_dir() .. "/classpath.txt")

	compile_sources(build_tool.get_sources(), build_tool.get_output_dir(), build_tool.get_dependencies_classpath())
	compile_test_sources(build_tool)

	-- PREPARE DEBUG TEST COMMAND
	local junit = command:build_junit(port)
	log.debug("junit debug command: ", junit.command, " ", table.concat(junit.args, " "))
	local terminated_command_event = run_debug_test(junit.command, junit.args, log_file)

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
			output = log_file,
			terminated_command_event = terminated_command_event,
		},
	}
end

return SpecBuilder
