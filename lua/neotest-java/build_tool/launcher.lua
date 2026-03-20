local log = require("neotest-java.logger")
local nio = require("nio")
local Job = require("plenary.job")
local lib = require("neotest.lib")

local _, repl = pcall(require, "dap.repl")

---@class neotest-java.BuildToolLauncher
local launcher = {}

---@param command string
---@param args string[]
---@param cwd neotest-java.Path
---@return nio.control.Event
function launcher.launch_debug_test(command, args, cwd)
	lib.notify("Running debug test", vim.log.levels.INFO)
	log.trace("run_debug_test function")

	local test_command_started_listening = nio.control.event()
	local terminated_command_event = nio.control.event()

	local stderr = {}
	local job = Job:new({
		command = command,
		cwd = cwd:to_string(),
		args = args,
		on_stderr = function(_, data)
			if data == nil then
				return
			end
			stderr[#stderr + 1] = data
			if repl then
				vim.schedule(function()
					repl.append(data)
				end)
			end
		end,
		on_stdout = function(_, data)
			if data == nil then
				return
			end
			if string.find(data, "Listening") then
				test_command_started_listening.set()
			end
			if repl then
				vim.schedule(function()
					repl.append(data)
				end)
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
	if repl then
		repl.clear()
	end
	job:start()
	test_command_started_listening.wait()

	return terminated_command_event
end

return launcher
