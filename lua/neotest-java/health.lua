local health = vim.health or require("health")
local binaries = require("neotest-java.command.binaries")

local function check_bin(name)
	if vim.fn.executable(name) == 1 then
		local path = vim.fn.exepath(name)
		health.ok(string.format("'%s' is installed at %s", name, path))
	else
		health.error(string.format("'%s' not found", name))
	end
end

return {
	check = function()
		check_bin(binaries.java())
		check_bin(binaries.javac())
	end,
}
