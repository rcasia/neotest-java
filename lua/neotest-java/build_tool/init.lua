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
