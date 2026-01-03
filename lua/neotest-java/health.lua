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

local function check_treesitter()
	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok then
		health.error("'nvim-treesitter' is not installed", {
			"Install it: https://github.com/nvim-treesitter/nvim-treesitter",
		})
		return
	end
	if not parsers.has_parser("java") then
		health.error("Tree-sitter parser for 'java' is missing", {
			"Run :TSInstall java",
		})
	else
		health.ok("Tree-sitter parser for 'java' is installed")
	end
	health.warn("Make sure Tree-sitter parser for 'java' is up-to-date", {
		"Run :TSUpdate java",
	})
end

local function check_plugin(mod_name, repo_url)
	local ok = pcall(require, mod_name)
	if ok then
		health.ok(string.format("Plugin '%s' is installed", mod_name))
	else
		health.error(string.format("Plugin '%s' is missing", mod_name), {
			"Install it: https://github.com/" .. repo_url,
		})
	end
end

return {
	check = function()
		health.start("Neovim version check")
		if vim.fn.has("nvim-0.10.4") == 1 then
			health.ok("Neovim version is OK")
		else
			health.error("Neovim 0.10.4+ is required")
		end

		health.start("Required plugin dependencies")
		check_plugin("neotest", "nvim-neotest/neotest")
		check_plugin("nvim-treesitter", "nvim-treesitter/nvim-treesitter")
		check_treesitter()
		check_plugin("nio", "nvim-neotest/nvim-nio")
		check_plugin("plenary", "nvim-lua/plenary.nvim")
		check_plugin("jdtls", "mfussenegger/nvim-jdtls")

		health.start("Required plugin dependencies for debugging")
		check_plugin("dap", "mfussenegger/nvim-dap")
		check_plugin("dapui", "rcarriga/nvim-dap-ui")
		check_plugin("nvim-dap-virtual-text", "theHamsta/nvim-dap-virtual-text")

		health.start("Required binaries")
		check_bin(binaries.java())
	end,
}
