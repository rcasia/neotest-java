local assertions = require("tests.assertions")
local eq = assertions.eq
local nio = require("nio")
local it = nio.tests.it

local CommandExecutor = require("neotest-java.command.command_executor")

describe("Command Executor (Integration Test)", function()
	local executor
	-- Use the currently running Neovim executable as our test binary
	local nvim_bin = vim.v.progpath

	before_each(function()
		executor = CommandExecutor()
	end)

	it("captures stdout from a successful command", function()
		-- running: nvim --version
		local result = executor.execute_command(nvim_bin, { "--version" })

		eq(0, result.exit_code)
		-- Verify it outputted something resembling a version string
		assert(result.stdout:match("NVIM"), "Stdout should contain NVIM")
		eq("", result.stderr)
	end)

	it("captures stderr and exit code from a failing command", function()
		-- running: nvim --invalid-flag
		local result = executor.execute_command(nvim_bin, { "--invalid-flag" })

		-- Neovim returns exit code 1 on invalid flags
		eq(1, result.exit_code)
		eq("", result.stdout)
		-- It should print error usage to stderr
		assert(result.stderr:len() > 0, "Stderr should not be empty")
	end)

	it("returns specific error code when command binary does not exist", function()
		local status, _ = pcall(executor.execute_command, "non_existent_command_12345", {})
		eq(false, status)
	end)
end)
