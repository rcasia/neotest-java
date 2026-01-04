local options = {
	setup = function()
		local ch = require("neotest-java.context_holder")
		local adapter = assert(ch.adapter)

		adapter.install()
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
