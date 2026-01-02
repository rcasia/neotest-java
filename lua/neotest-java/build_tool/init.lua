local maven = require("neotest-java.build_tool.maven")
local gradle = require("neotest-java.build_tool.gradle")
local log = require("neotest-java.logger")
local nio = require("nio")
local Job = require("plenary.job")
local lib = require("neotest.lib")
local repl = require("dap.repl")

---@class neotest-java.BuildTool
---@field get_build_dirname fun(): neotest-java.Path
---@field get_project_filename fun(): string
---@field get_module_dependencies fun(root: string): table
---@field get_spring_property_filepaths fun(roots: neotest-java.Path[]): neotest-java.Path[]

---@type table<string, neotest-java.BuildTool>
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
---@param cwd string
---@return nio.control.Event
build_tools.launch_debug_test = function(command, args, cwd)
	lib.notify("Running debug test", vim.log.levels.INFO)
	log.trace("run_debug_test function")

	local test_command_started_listening = nio.control.event()
	local terminated_command_event = nio.control.event()

	local stderr = {}
	local job = Job:new({
		command = command,
		cwd = cwd,
		args = args,
		on_stderr = function(_, data)
			if data == nil then
				return
			end
			stderr[#stderr + 1] = data
			vim.schedule(function()
				repl.append(data)
			end)
		end,
		on_stdout = function(_, data)
			if data == nil then
				return
			end
			if string.find(data, "Listening") then
				test_command_started_listening.set()
			end
			vim.schedule(function()
				repl.append(data)
			end)
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
	repl.clear()
	job:start()
	test_command_started_listening.wait()

	return terminated_command_event
end

return build_tools
