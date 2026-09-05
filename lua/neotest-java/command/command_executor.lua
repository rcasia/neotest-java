local nio = require("nio")
local logger = require("neotest-java.logger")

local async_system = nio.wrap(function(cmd, args, cb)
	vim.system(vim.list_extend({ cmd }, args), {}, function(obj)
		cb(obj)
	end)
end, 3)

--- @class neotest-java.CommandExecutor
--- @field execute_command fun(command: string, args: string[]): { stdout: string, stderr: string, exit_code: number }

local CommandExecutor = function()
	--- @type neotest-java.CommandExecutor
	return {
		execute_command = function(command, args)
			logger.debug("Executing command:", command, "with args:", args)
			local ok, result = pcall(async_system, command, args or {})
			if not ok then
				logger.error("Command execution failed to start:", result)
				return {
					stdout = "",
					stderr = tostring(result),
					exit_code = -1,
				}
			end

			logger.debug(
				"Command finished with exit code:",
				result.code,
				"stdout len:",
				result.stdout and #result.stdout or 0,
				"stderr len:",
				result.stderr and #result.stderr or 0
			)
			if result.code and result.code ~= 0 then
				logger.error("Command failed. Stderr:", result.stderr)
			end

			return {
				stdout = result.stdout or "",
				stderr = result.stderr or "",
				exit_code = result.code or 0,
			}
		end,
	}
end

return CommandExecutor
