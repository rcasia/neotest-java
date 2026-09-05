local async = require("tests.async_helpers").async
local assertions = require("tests.assertions")
local eq = assertions.eq
local MiniTest = require("mini.test")

local Path = require("neotest-java.model.path")
local BuildToolLauncher = require("neotest-java.build_tool.launcher").new
-- dap_repl = false: this environment has no nvim-dap installed. In real
-- usage `spec_builder` already asserts `require("dap")` succeeds before
-- reaching `launch_debug_test` (see core/spec_builder/init.lua), so the
-- real dap.repl module would be present too. Here we only care about the
-- job-spawn + JDWP-wait behavior, not the dap.repl integration.
local launcher = BuildToolLauncher({ dap_repl = false })

--- Real-process integration coverage for `launcher.launch_debug_test`.
---
--- This spawns an actual JVM with a JDWP debug agent (the same mechanism
--- neotest-java uses to run tests under `strategy = "dap"`), without
--- attaching a real debugger. A JVM started with
--- `-agentlib:jdwp=...,suspend=n` prints
--- "Listening for transport dt_socket at address: <port>" to stdout as
--- soon as the debug socket is open, then continues running normally.
---
--- This exercises the real `plenary.job` spawn + JDWP "Listening" wait +
--- process-exit logic end-to-end, which is the exact behavior a future
--- non-plenary implementation (see #317) must preserve.
describe("BuildToolLauncher (real JVM integration)", function()
	it(
		"detects the JDWP 'Listening' message from a real JVM and waits for it to exit",
		async(function()
			if vim.fn.executable("java") == 0 then
				MiniTest.skip("java executable not found on PATH; skipping real-JVM integration test")
				return
			end

			local args = {
				"-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=0",
				"-version",
			}

			local terminated_event = launcher.launch_debug_test("java", args, Path(vim.uv.cwd()))

			-- `launch_debug_test` only returns once the JVM has printed the
			-- "Listening" line, proving the real plenary.job stdout wiring
			-- correctly detects it.
			assert(terminated_event ~= nil, "should return a terminated_command_event")

			-- `java -version` exits almost immediately once started; wait for
			-- the process-exit event to prove on_exit fires for a real job.
			terminated_event.wait()
			eq(true, terminated_event.is_set())
		end)
	)
end)
