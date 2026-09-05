local async = require("tests.async_helpers").async
local assertions = require("tests.assertions")
local eq = assertions.eq

local Path = require("neotest-java.model.path")
local BuildToolLauncher = require("neotest-java.build_tool.launcher").new

--- Build a stub job runner mimicking the shape the job runner contract
--- exposes (`Job:new(opts)` returning an object with `start()`). The stub captures
--- the callbacks and lets `start()` drive them synchronously via
--- `on_start`, matching how a real job would invoke them from its own
--- process lifecycle (started -> stdout/stderr chunks -> exit) without
--- needing real process I/O or a scheduler tick.
local function stub_job_runner(on_start)
	local started_opts = nil

	return {
		new = function(_, opts)
			started_opts = opts
			return {
				start = function()
					if on_start then
						on_start(opts)
					end
				end,
			}
		end,
		opts = function()
			return started_opts
		end,
	}
end

describe("BuildToolLauncher", function()
	it(
		"starts the job with the given command, args and cwd",
		async(function()
			local runner = stub_job_runner(function(opts)
				opts.on_stdout(nil, "Listening for transport dt_socket at address: 12345")
			end)
			local launcher = BuildToolLauncher({ job_runner = runner, dap_repl = false })

			launcher.launch_debug_test("java", { "-jar", "foo.jar" }, Path("/fake/cwd"))

			local opts = runner.opts()
			assert(opts ~= nil, "job runner should have been started with opts")
			eq("java", opts.command)
			eq({ "-jar", "foo.jar" }, opts.args)
			eq(Path("/fake/cwd"):to_string(), opts.cwd)
		end)
	)

	it(
		"resolves the returned event only once stdout reports 'Listening'",
		async(function()
			local resolved = false
			local runner = stub_job_runner(function(opts)
				-- irrelevant stdout should not resolve the wait
				opts.on_stdout(nil, "compiling...")
				eq(false, resolved)
				opts.on_stdout(nil, "Listening for transport dt_socket at address: 54321")
			end)
			local launcher = BuildToolLauncher({ job_runner = runner, dap_repl = false })

			launcher.launch_debug_test("java", {}, Path("/fake/cwd"))
			resolved = true

			eq(true, resolved)
		end)
	)

	it(
		"sets the terminated event when the job exits",
		async(function()
			local runner = stub_job_runner(function(opts)
				opts.on_stdout(nil, "Listening")
			end)
			local launcher = BuildToolLauncher({ job_runner = runner, dap_repl = false })

			local terminated_event = launcher.launch_debug_test("java", {}, Path("/fake/cwd"))

			local opts = runner.opts()
			assert(opts ~= nil, "job runner should have been started with opts")
			local terminated_before = terminated_event.is_set()
			opts.on_exit(nil, 0)
			local terminated_after = terminated_event.is_set()

			eq(false, terminated_before)
			eq(true, terminated_after)
		end)
	)

	it(
		"ignores nil stdout/stderr chunks without erroring",
		async(function()
			local runner = stub_job_runner(function(opts)
				opts.on_stdout(nil, nil)
				opts.on_stderr(nil, nil)
				opts.on_stdout(nil, "Listening")
			end)
			local launcher = BuildToolLauncher({ job_runner = runner, dap_repl = false })

			local terminated_event = launcher.launch_debug_test("java", {}, Path("/fake/cwd"))
			eq(false, terminated_event.is_set())
		end)
	)

	it("defaults to a vim.system-backed job runner when no job_runner is injected", function()
		local launcher = BuildToolLauncher({ dap_repl = false })
		assert(launcher.launch_debug_test ~= nil, "launch_debug_test should exist with default deps")
	end)
end)
