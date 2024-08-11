local maven = require("neotest-java.build_tool.maven")
local gradle = require("neotest-java.build_tool.gradle")
local log = require("neotest-java.logger")
local nio = require("nio")
local Job = require("plenary.job")
local lib = require("neotest.lib")
local binaries = require("neotest-java.command.binaries")

---@class neotest-java.BuildTool
---@field get_dependencies_classpath fun(): string
---@field get_output_dir fun(): string
---@field prepare_classpath fun()
---@field get_sources fun(): string[]
---@field source_dir fun(): string
---@field get_test_sources fun(): string[]
---@field get_resources fun(): string[]

local build_tools = { gradle = gradle, maven = maven }

--- will determine the build tool to use
---@return neotest-java.BuildTool
build_tools.get = function(project_type)
	if not build_tools[project_type] then
		error("unknown project type: " .. project_type)
	end
	return build_tools[project_type]
end

build_tools.compile_sources = function(project_type)
	lib.notify("Compiling sources", vim.log.levels.INFO)

	local build_tool = build_tools.get(project_type)
	build_tool.prepare_classpath()

	local compilation_errors = {}
	local status_code = 0
	local sources = build_tool.get_sources()
	local output_dir = build_tool.get_output_dir()
	local source_compilation_command_exited = nio.control.event()
	local source_compilation_args = {
		"-Xlint:none",
		"-parameters",
		"-d",
		output_dir .. "/classes",
		"@" .. output_dir .. "/cp_arguments.txt",
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
				lib.notify("Error compiling sources", vim.log.levels.ERROR)
				log.error("test compilation error args: ", vim.inspect(source_compilation_args))
				error("Error compiling sources: " .. table.concat(compilation_errors, "\n"))
			end
		end,
	}):start()
	source_compilation_command_exited.wait()
	assert(status_code == 0, "Error compiling sources")
end

build_tools.compile_test_sources = function(project_type)
	lib.notify("Compiling test sources", vim.log.levels.INFO)
	local build_tool = build_tools.get(project_type)

	local compilation_errors = {}
	local status_code = 0
	local output_dir = build_tool.get_output_dir()

	local test_compilation_command_exited = nio.control.event()
	local test_sources_compilation_args = {
		"-Xlint:none",
		"-parameters",
		"-d",
		output_dir .. "/classes",
		("@%s/cp_arguments.txt"):format(output_dir),
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
				lib.notify("Error compiling test sources", vim.log.levels.ERROR)
				log.error("test compilation error args: ", vim.inspect(test_sources_compilation_args))
				error("Error compiling test sources: " .. table.concat(compilation_errors, "\n"))
			end
		end,
	}):start()
	test_compilation_command_exited.wait()
	assert(status_code == 0, "Error compiling test sources")
end

---@param command string
---@param args string[]
---@return nio.control.Event
build_tools.launch_debug_test = function(command, args)
	lib.notify("Running debug test", vim.log.levels.INFO)
	log.trace("run_debug_test function")

	local test_command_started_listening = nio.control.event()
	local terminated_command_event = nio.control.event()

	local stderr = {}
	local job = Job:new({
		command = command,
		args = args,
		on_stderr = function(_, data)
			stderr[#stderr + 1] = data
		end,
		on_stdout = function(err, data)
			if string.find(data, "Listening") then
				test_command_started_listening.set()
			end
		end,
		on_exit = function(_, code)
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

return build_tools
