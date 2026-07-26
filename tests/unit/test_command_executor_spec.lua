local async = require("tests.async_helpers").async
local assertions = require("tests.assertions")
local eq = assertions.eq

local CommandExecutor = require("neotest-java.command.command_executor")

describe("Command Executor", function()
	it(
		"runs a command and captures stdout",
		async(function()
			local executor = CommandExecutor()
			local cmd = vim.fn.has("win32") == 1 and "cmd.exe" or "echo"
			local args = vim.fn.has("win32") == 1 and { "/c", "echo", "hello" } or { "hello" }

			local result = executor.execute_command(cmd, args)

			eq(0, result.exit_code)
			eq("", result.stderr)
			assert(
				vim.trim(result.stdout) == "hello",
				"stdout should contain 'hello', got: " .. vim.inspect(result.stdout)
			)
		end)
	)

	it(
		"captures non-zero exit codes",
		async(function()
			local executor = CommandExecutor()
			local cmd = vim.fn.has("win32") == 1 and "cmd.exe" or "false"
			local args = vim.fn.has("win32") == 1 and { "/c", "exit", "1" } or {}

			local result = executor.execute_command(cmd, args)

			eq(1, result.exit_code)
		end)
	)

	it(
		"captures stderr output",
		async(function()
			local executor = CommandExecutor()
			local cmd = vim.fn.has("win32") == 1 and "cmd.exe" or "bash"
			local args = vim.fn.has("win32") == 1 and { "/c", "echo", "error", ">&2" }
				or { "-c", "echo 'error message' >&2" }

			local result = executor.execute_command(cmd, args)

			eq(0, result.exit_code)
			assert(result.stderr:match("error"), "stderr should contain 'error', got: " .. vim.inspect(result.stderr))
		end)
	)

	it(
		"handles commands with multiple arguments",
		async(function()
			local executor = CommandExecutor()
			local cmd = vim.fn.has("win32") == 1 and "cmd.exe" or "echo"
			local args = vim.fn.has("win32") == 1 and { "/c", "echo", "hello", "world" } or { "hello", "world" }

			local result = executor.execute_command(cmd, args)

			eq(0, result.exit_code)
			assert(
				vim.trim(result.stdout) == "hello world",
				"stdout should be 'hello world', got: " .. vim.inspect(result.stdout)
			)
		end)
	)
end)
