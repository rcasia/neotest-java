local async = require("tests.async_helpers").async
local eq = require("tests.assertions").eq
local MiniTest = require("mini.test")
local Path = require("neotest-java.model.path")
local BuildToolLauncher = require("neotest-java.build_tool.launcher").new
local launcher = BuildToolLauncher({ dap_repl = false })

local function java(args, opts)
	return launcher.launch_debug_test("java", args, Path(vim.uv.cwd()), opts)
end

local function with_java(fn)
	return async(function()
		if vim.fn.executable("java") == 0 then
			MiniTest.skip("java executable not found on PATH")
			return
		end
		fn()
	end)
end

describe("BuildToolLauncher (real JVM integration)", function()
	it(
		"detects JDWP and waits for a real JVM exit",
		with_java(function()
			local process = java({ "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=0", "-version" })
			eq(true, process.state.ready)
			eq(0, process.wait().code)
			eq(true, process.is_set())
		end)
	)

	for _, arg in ipairs({ "-version", "-not-a-valid-java-option" }) do
		it(
			"settles a real JVM exit before readiness: " .. arg,
			with_java(function()
				local ok, err = pcall(java, { arg }, { startup_timeout_ms = 2000 })
				eq(false, ok)
				assert(tostring(err):find("before JDWP readiness", 1, true))
			end)
		)
	end

	it(
		"reaps a suspended JVM after bounded exit/report wait",
		with_java(function()
			local process = java({ "-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=0", "-version" }, {
				exit_timeout_ms = 20,
				shutdown_timeout_ms = 20,
			})
			local state = process.wait_exit()
			eq(true, state.cancelled)
			eq(true, state.exited)
			assert(state.error:find("exit/report", 1, true))
			local alive = vim.uv.kill(state.pid, 0)
			assert(not alive, "the invocation's JVM must be reaped")
		end)
	)

	it(
		"settles executable spawn failure",
		async(function()
			local ok, err =
				pcall(launcher.launch_debug_test, "no-such-java-executable-neotest-342", {}, Path(vim.uv.cwd()))
			eq(false, ok)
			assert(tostring(err):find("Could not start Java test", 1, true))
		end)
	)
end)
