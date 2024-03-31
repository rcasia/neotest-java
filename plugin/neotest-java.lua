local exists = require("neotest.lib.file").exists
local job = require("plenary.job")

local options = {
	setup = function()
		if exists(vim.fn.stdpath("data") .. "/neotest-java/junit-platform-console-standalone-1.10.1.jar") then
			print("Already setup!")
			return
		end

		-- Download Junit Standalone Jar
		local stderr = {}
		job
			:new({
				command = "curl",
				args = {
					"--output",
					vim.fn.stdpath("data") .. "/neotest-java/junit-platform-console-standalone-1.10.1.jar",
					"https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/1.10.1/junit-platform-console-standalone-1.10.1.jar",
				},
				on_stderr = function(_, data)
					table.insert(stderr, data)
				end,
			})
			:sync(10000)

		-- if any error
		if #stderr ~= 0 then
			error(table.concat(stderr, "\n"))
		end
	end,
}

vim.api.nvim_create_user_command("NeotestJava", function(info)
	local fun = options[info.args] or error("Invalid option")
	fun()
end, {
	desc = "Setup neotest-java",
	nargs = 1,
	complete = function()
		-- keys from options
		return vim.tbl_keys(options)
	end,
})
