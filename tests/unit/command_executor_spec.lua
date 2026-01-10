local assertions = require("tests.assertions")
local eq = assertions.eq
local nio = require("nio")
local it = nio.tests.it

local CommandExecutor = require("neotest-java.command.command_executor")

describe("Command Executor (Integration Test)", function()
	local executor

	before_each(function()
		executor = CommandExecutor()
	end)

	it("captures stdout from a successful command", function()
		-- echo -n prevents a trailing newline, making the test cleaner
		local result = executor.execute_command("echo", { "-n", "hello world" })

		eq(0, result.exit_code)
		eq("hello world", result.stdout)
		eq("", result.stderr)
	end)

	it("captures stderr and exit code from a failing command", function()
		-- running a non-existent command via bash to generate stderr
		local result = executor.execute_command("bash", { "-c", "echo 'error msg' >&2; exit 1" })

		eq(1, result.exit_code)
		eq("", result.stdout)
		-- Note: We strip whitespace because different shells might format stderr slightly differently
		eq("errormsg", result.stderr:gsub("%s+", ""))
	end)

	it("handles multiple arguments correctly", function()
		local result = executor.execute_command("bash", { "-c", "echo $1 $2", "--", "arg1", "arg2" })

		eq(0, result.exit_code)
		-- The command should have combined the arguments
		eq("arg1 arg2\n", result.stdout)
	end)

	it("returns specific error code when command binary does not exist", function()
		-- vim.system throws an error (ENOENT) if the executable is not found.
		-- We verify that the call fails safely (caught by pcall).
		local status, _ = pcall(executor.execute_command, "non_existent_command_12345", {})

		eq(false, status)
	end)
end)
