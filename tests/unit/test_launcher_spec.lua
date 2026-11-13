local async = require("tests.async_helpers").async
local eq = require("tests.assertions").eq
local Path = require("neotest-java.model.path")
local BuildToolLauncher = require("neotest-java.build_tool.launcher").new
local BANNER = "Listening for transport dt_socket at address: 12345"

local function fixture(on_start)
	local opts, kills
	kills = {}
	local launcher = BuildToolLauncher({
		dap_repl = false,
		job_runner = {
			new = function(_, callbacks)
				opts = callbacks
				return {
					start = function()
						on_start(callbacks)
						return {
							kill = function(_, signal)
								kills[#kills + 1] = signal
								if signal == 9 then
									callbacks.on_exit(nil, 137, 9)
								end
							end,
						}
					end,
				}
			end,
		},
	})
	return launcher, function()
		return opts, kills
	end
end

local function launch(launcher, opts)
	return launcher.launch_debug_test("java", { "-jar", "test.jar" }, Path("/fake/cwd"), opts)
end

describe("BuildToolLauncher", function()
	it(
		"retains the system handle and the legacy bounded event API",
		async(function()
			local launcher, inspect = fixture(function(opts)
				opts.on_stdout(nil, BANNER)
			end)
			local process = launch(launcher)
			local opts = inspect()
			eq("java", opts.command)
			eq({ "-jar", "test.jar" }, opts.args)
			eq(tostring(Path("/fake/cwd")), opts.cwd)
			eq(false, process.is_set())
			opts.on_exit(nil, 0, 0)
			opts.on_exit(nil, 8, 0) -- duplicate completion cannot overwrite the outcome
			eq(true, process.is_set())
			eq(0, process.wait().code)
		end)
	)

	for _, stream in ipairs({ "on_stdout", "on_stderr" }) do
		it(
			"recognizes split JDWP readiness on " .. stream,
			async(function()
				local launcher, inspect = fixture(function(opts)
					opts[stream](nil, nil)
					opts[stream](nil, "Listening for transport dt_")
					opts[stream](nil, "socket at address: 99")
				end)
				local process = launch(launcher)
				eq(true, process.state.ready)
				inspect().on_exit(nil, 0)
			end)
		)
	end

	for _, code in ipairs({ 0, 1, 7 }) do
		it(
			"fails promptly on pre-readiness exit " .. code,
			async(function()
				local launcher = fixture(function(opts)
					opts.on_stderr(nil, "broken classpath")
					opts.on_exit(nil, code)
				end)
				local ok, err = pcall(launch, launcher)
				eq(false, ok)
				assert(tostring(err):find("before JDWP readiness", 1, true))
				assert(tostring(err):find("broken classpath", 1, true))
			end)
		)
	end

	it(
		"settles startup exceptions",
		async(function()
			local launcher = fixture(function()
				error("spawn exploded")
			end)
			local ok, err = pcall(launch, launcher)
			eq(false, ok)
			assert(tostring(err):find("spawn exploded", 1, true))
		end)
	)

	it(
		"bounds missing readiness and escalates only its owned process",
		async(function()
			local launcher, inspect = fixture(function(opts)
				opts.on_stdout(nil, "Listening is not a JDWP banner")
			end)
			local ok, err = pcall(launch, launcher, { startup_timeout_ms = 10, shutdown_timeout_ms = 10 })
			eq(false, ok)
			assert(tostring(err):find("Timed out", 1, true))
			local _, kills = inspect()
			eq({ 15, 9 }, kills)
		end)
	)

	it(
		"bounds exit and makes cancellation idempotent",
		async(function()
			local launcher, inspect = fixture(function(opts)
				opts.on_stdout(nil, BANNER)
			end)
			local process = launch(launcher, { exit_timeout_ms = 10, shutdown_timeout_ms = 10 })
			local state = process.wait_exit()
			eq(true, state.cancelled)
			process.stop("another cancellation")
			eq(true, state.exited)
			local _, kills = inspect()
			eq({ 15, 9 }, kills)
			assert(state.error:find("exit/report", 1, true))
		end)
	)

	it(
		"reaps an unclaimed ready process without limiting a claimed debugger",
		async(function()
			local launcher, inspect = fixture(function(opts)
				opts.on_stdout(nil, BANNER)
			end)
			local process = launch(launcher, { attach_timeout_ms = 10, shutdown_timeout_ms = 10 })
			eq(true, process.wait_exit(200).exited)
			local _, kills = inspect()
			eq({ 15, 9 }, kills)
			local other, inspect_other = fixture(function(opts)
				opts.on_stdout(nil, BANNER)
			end)
			local claimed = launch(other, { attach_timeout_ms = 10 })
			claimed.claim()
			require("nio").wrap(function(callback)
				local timer = vim.uv.new_timer()
				timer:start(30, 0, function()
					timer:close()
					callback()
				end)
			end, 1)()
			eq(false, claimed.state.cancelled)
			inspect_other().on_exit(nil, 0)
		end)
	)

	it(
		"does not stop a concurrent invocation",
		async(function()
			local first, inspect_first = fixture(function(opts)
				opts.on_stdout(nil, BANNER)
			end)
			local second, inspect_second = fixture(function(opts)
				opts.on_stdout(nil, BANNER)
			end)
			local a = launch(first, { shutdown_timeout_ms = 10 })
			local b = launch(second)
			a.stop()
			eq(true, a.wait_exit(200).exited)
			local _, first_kills = inspect_first()
			local _, second_kills = inspect_second()
			eq({ 15, 9 }, first_kills)
			eq({}, second_kills)
			eq(false, b.state.cancelled)
			inspect_second().on_exit(nil, 0)
		end)
	)
	it(
		"reaps startup even if the readiness task is cancelled",
		async(function()
			local nio = require("nio")
			local launcher, inspect = fixture(function() end)
			local task = nio.run(function()
				launch(launcher, { startup_timeout_ms = 10, shutdown_timeout_ms = 10 })
			end, function() end)
			task.cancel()
			nio.wrap(function(callback)
				local timer = vim.uv.new_timer()
				timer:start(50, 0, function()
					timer:close()
					callback()
				end)
			end, 1)()
			local _, kills = inspect()
			eq({ 15, 9 }, kills)
		end)
	)
end)
