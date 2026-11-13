local log = require("neotest-java.logger")
local nio = require("nio")

--- @class neotest-java.SystemProcess
--- @field pid? number
--- @field kill fun(self: table, signal: number)

--- @class neotest-java.JobRunner
--- @field new fun(self: neotest-java.JobRunner, opts: table): { start: fun(): neotest-java.SystemProcess? }
local default_job_runner = {
	new = function(_, opts)
		return {
			start = function()
				return vim.system(vim.list_extend({ opts.command }, opts.args), {
					cwd = opts.cwd,
					stdout = opts.on_stdout,
					stderr = opts.on_stderr,
				}, function(obj)
					opts.on_exit(nil, obj.code, obj.signal)
				end)
			end,
		}
	end,
}

local active = {}
vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		for process in pairs(active) do
			process.stop("Neovim exiting", true)
		end
	end,
})

local function close_timer(timer)
	if timer and not timer:is_closing() then
		timer:stop()
		timer:close()
	end
end

local function timer_after(ms, callback)
	local timer = assert(vim.uv.new_timer())
	timer:start(ms, 0, callback)
	return timer
end

--- @class neotest-java.DebugProcess
--- @field wait fun(): table Legacy termination-event API, now bounded.
--- @field is_set fun(): boolean
--- @field wait_ready fun(): table
--- @field wait_exit fun(timeout_ms?: number): table
--- @field stop fun(reason?: string, force?: boolean)
--- @field claim fun() Transfer startup ownership to the DAP strategy.
--- @field state table

---@param deps neotest-java.BuildToolLauncherDeps | nil
local function BuildToolLauncher(deps)
	deps = deps or {}
	deps.job_runner = deps.job_runner or default_job_runner
	if deps.dap_repl == nil then
		local ok, repl = pcall(require, "dap.repl")
		deps.dap_repl = ok and repl or false
	end

	return {
		launch_debug_test = function(command, args, cwd, opts)
			opts = opts or {}
			local startup_ms = opts.startup_timeout_ms or 30000
			local exit_ms = opts.exit_timeout_ms or 5000
			local shutdown_ms = opts.shutdown_timeout_ms or 1000
			local ready, exited = nio.control.event(), nio.control.event()
			local state = { ready = false, exited = false, cancelled = false, stderr = "" }
			local process, system, startup_timer, orphan_timer, kill_timer
			local wait_timers = {}
			local output_tail = { stdout = "", stderr = "" }
			local repl = deps.dap_repl

			local failure_cleaned = false
			local function cleanup_failure()
				if failure_cleaned or not opts.on_failure then
					return
				end
				failure_cleaned = true
				-- Independent of build_spec's task: a cancelled readiness waiter
				-- cannot execute its own finally/cleanup path.
				vim.schedule(function()
					nio.run(opts.on_failure, function(ok, err)
						if not ok then
							log.error("Could not clean Java test reports: " .. tostring(err))
						end
					end)
				end)
			end

			local function finish(code, signal)
				if state.exited then
					return
				end
				state.exited, state.code, state.signal = true, code, signal
				if not state.ready and not state.error then
					state.error = "Java exited before JDWP readiness (code " .. tostring(code) .. ")"
				end
				if state.error then
					cleanup_failure()
				end
				close_timer(startup_timer)
				close_timer(orphan_timer)
				close_timer(kill_timer)
				active[process] = nil
				exited.set()
				for timer, event in pairs(wait_timers) do
					close_timer(timer)
					event.set()
				end
				ready.set()
			end

			local function kill(signal)
				if system and not state.exited then
					local ok, err = pcall(system.kill, system, signal)
					if not ok then
						log.error("Could not stop test JVM: " .. tostring(err))
					end
				end
			end

			process = {
				state = state,
				is_set = exited.is_set,
				claim = function()
					assert(not state.cancelled, state.error)
					close_timer(orphan_timer)
				end,
				stop = function(reason, force)
					if force then
						kill(9)
					end
					if state.exited or state.cancelled then
						return
					end
					state.cancelled = true
					state.error = reason or "Java debug test cancelled"
					close_timer(startup_timer)
					close_timer(orphan_timer)
					ready.set()
					kill(force and 9 or 15)
					if not state.exited and not force then
						kill_timer = timer_after(shutdown_ms, function()
							close_timer(kill_timer)
							kill(9)
						end)
					end
				end,
				wait_ready = function()
					ready.wait()
					return state
				end,
				wait_exit = function(timeout_ms)
					if state.exited then
						return state
					end
					local done = nio.control.event()
					-- A per-wait timer bounds even a missing OS exit callback. Polling
					-- avoids retaining event waiters after timeout or task cancellation.
					local timer = assert(vim.uv.new_timer())
					local reaping = state.cancelled
					local deadline = vim.uv.hrtime()
						+ (reaping and (shutdown_ms + 1000) or (timeout_ms or exit_ms)) * 1e6
					wait_timers[timer] = done
					timer:start(0, 10, function()
						if state.exited or vim.uv.hrtime() >= deadline then
							if not state.exited and not reaping then
								reaping = true
								deadline = vim.uv.hrtime() + (shutdown_ms + 1000) * 1e6
								process.stop("Timed out waiting for Java test exit/report")
								return
							end
							if not state.exited then
								cleanup_failure()
							end
							wait_timers[timer] = nil
							close_timer(timer)
							done.set()
						end
					end)
					done.wait()
					return state
				end,
			}
			process.wait = process.wait_exit
			active[process] = true

			local function output(stream, data)
				if not data then
					return
				end
				output_tail[stream] = (output_tail[stream] .. data):sub(-8192)
				if stream == "stderr" then
					state.stderr = output_tail.stderr
				end
				-- The JVM can split the banner across chunks or write it to stderr.
				if
					not state.cancelled
					and output_tail[stream]:find("Listening for transport dt_socket at address:", 1, true)
				then
					state.ready = true
					close_timer(startup_timer)
					ready.set()
				end
				if repl then
					vim.schedule(function()
						repl.append(data)
					end)
				end
			end

			startup_timer = timer_after(startup_ms, function()
				process.stop("Timed out waiting for Java JDWP readiness")
			end)
			-- Also reap a ready JVM if build_spec's caller is cancelled before
			-- handing the spec to Neotest. Claiming it does not limit debug time.
			orphan_timer = timer_after(opts.attach_timeout_ms or 120000, function()
				process.stop("Java debug test was never claimed by DAP")
			end)
			local ok, err = pcall(function()
				if repl then
					repl.clear()
				end
				local job = deps.job_runner:new({
					command = command,
					args = args,
					cwd = cwd:to_string(),
					on_stdout = function(_, data)
						output("stdout", data)
					end,
					on_stderr = function(_, data)
						output("stderr", data)
					end,
					on_exit = function(_, code, signal)
						finish(code, signal)
					end,
				})
				system = job:start()
				state.pid = system and system.pid or nil
			end)
			if not ok then
				state.error = "Could not start Java test: " .. tostring(err)
				finish(-1, 0)
			end
			process.wait_ready()
			if not state.ready or state.cancelled then
				process.stop(state.error)
				process.wait_exit(shutdown_ms + 1000)
				error((state.error or "Java debug startup failed") .. "\n" .. state.stderr)
			end
			return process
		end,
	}
end

---@class neotest-java.BuildToolLauncherDeps
---@field job_runner? neotest-java.JobRunner
---@field dap_repl? false | { append: fun(data: string), clear: fun() }

---@class neotest-java.BuildToolLauncher
---@field launch_debug_test fun(command: string, args: string[], cwd: neotest-java.Path, opts?: table): neotest-java.DebugProcess
---@field new fun(deps: neotest-java.BuildToolLauncherDeps | nil): neotest-java.BuildToolLauncher
local launcher = BuildToolLauncher()
launcher.new = BuildToolLauncher
return launcher
