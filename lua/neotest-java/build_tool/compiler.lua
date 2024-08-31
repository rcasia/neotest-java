local log = require("neotest-java.logger")
local nio = require("nio")
local Job = require("plenary.job")
local lib = require("neotest.lib")
local binaries = require("neotest-java.command.binaries")
local build_tools = require("neotest-java.build_tool")
local read_file = require("neotest-java.util.read_file")

local Compiler = {}

Compiler.compile_sources = function(project_type)
	lib.notify("Compiling sources", vim.log.levels.INFO)

	local build_tool = build_tools.get(project_type)
	build_tool.prepare_classpath()

	local compilation_errors = {}
	local status_code = 0
	local sources = build_tool.get_sources()
	local output_dir = build_tool.get_output_dir()
	local source_compilation_command_exited = nio.control.event()
	local source_compilation_args = {
		"-g",
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

Compiler.compile_test_sources = function(project_type)
	lib.notify("Compiling test sources", vim.log.levels.INFO)
	local build_tool = build_tools.get(project_type)

	local compilation_errors = {}
	local status_code = 0
	local output_dir = build_tool.get_output_dir()

	local test_compilation_command_exited = nio.control.event()
	local test_sources_compilation_args = {
		"-g",
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

return Compiler
