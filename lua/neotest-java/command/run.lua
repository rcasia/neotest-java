local process = require("neotest.lib.process")

local function string_to_table(str)
	local result_table = {}
	for word in str:gmatch("%S+") do
		table.insert(result_table, word)
	end
	return result_table
end

---@param command string | string[]
local function run(command)
	if type(command) == "string" then
		command = string_to_table(command)
	end

	local exit_code, res = process.run(command, { stdout = true, stderr = true })
	assert(
		exit_code == 0,
		"error while running command " .. table.concat(command, " ") .. " exit code: " .. exit_code .. " " .. res.stderr
	)

	return res.stdout
end

return run
