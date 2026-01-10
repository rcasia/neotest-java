local nio = require("nio")

local CommandExecutor = function()
	--- @type neotest-java.CommandExecutor
	return {
		execute_command = function(command, args)
			local result = assert( --
				nio.process.run({ cmd = command, args = args or {} })
			)

			return {
				stdout = result.stdout.read() or "",
				stderr = result.stderr.read() or "",
				exit_code = result.result(true) or 0,
			}
		end,
	}
end

return CommandExecutor
