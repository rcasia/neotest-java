local log = require("neotest-java.logger")
local nio = require("nio")
local lib = require("neotest.lib")

--- A minimal shape of the job runner this module needs:
---   * `new(opts)` accepts `command`, `cwd`, `args`, `on_stderr`, `on_stdout`,
---     `on_exit` callback fields
---   * the returned job exposes a `start()` method
--- @class neotest-java.JobRunner
--- @field new fun(self: neotest-java.JobRunner, opts: table): { start: fun() }

--- Default job runner, built directly on `vim.system` (see #317), matching
--- the same `vim.system` usage already established in
--- `command/command_executor.lua`. Unlike that module this doesn't need
--- `nio.wrap`, since `launch_debug_test` below already waits on its own
--- `nio.control.event()` rather than blocking on the process exiting.
--- @type neotest-java.JobRunner
local default_job_runner = {
	new = function(_, opts)
		return {
			start = function()
				vim.system(vim.list_extend({ opts.command }, opts.args), {
					cwd = opts.cwd,
					stdout = opts.on_stdout,
					stderr = opts.on_stderr,
				}, function(obj)
					if opts.on_exit then
						opts.on_exit(nil, obj.code)
					end
				end)
			end,
		}
	end,
}

---@param deps neotest-java.BuildToolLauncherDeps | nil
---@return neotest-java.BuildToolLauncher
local function BuildToolLauncher(deps)
	deps = deps or {}
	deps.job_runner = deps.job_runner or default_job_runner
	deps.dap_repl = deps.dap_repl
	if deps.dap_repl == nil then
		local ok, repl = pcall(require, "dap.repl")
		deps.dap_repl = ok and repl or nil
	end

	return {
		---@param command string
		---@param args string[]
		---@param cwd neotest-java.Path
		---@return nio.control.Event
		launch_debug_test = function(command, args, cwd)
			lib.notify("Running debug test", vim.log.levels.INFO)
			log.trace("run_debug_test function")

			local repl = deps.dap_repl

			local test_command_started_listening = nio.control.event()
			local terminated_command_event = nio.control.event()

			local stderr = {}
			local job = deps.job_runner:new({
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
		end,
	}
end

---@class neotest-java.BuildToolLauncherDeps
---@field job_runner? neotest-java.JobRunner
---@field dap_repl? false | { append: fun(data: string), clear: fun() }

---@class neotest-java.BuildToolLauncher
---@field launch_debug_test fun(command: string, args: string[], cwd: neotest-java.Path): nio.control.Event
---@field new fun(deps: neotest-java.BuildToolLauncherDeps | nil): neotest-java.BuildToolLauncher

-- Module-level singleton, matching the previous `launcher.launch_debug_test`
-- call site contract (`require("neotest-java.build_tool.launcher").launch_debug_test(...)`).
local launcher = BuildToolLauncher()

-- Exposed for tests / future callers that want to inject a custom job_runner
-- (e.g. a stub) without going through the module-level singleton.
launcher.new = BuildToolLauncher

return launcher
