-- luacheck: ignore 122 212
-- Minimal Neovim config for containerized neotest-java testing
-- Loaded automatically by Docker container startup

local deps_dir = "/project/deps"

-- Add deps to Lua path (each dep has its modules under lua/)
for _, dep in ipairs({
	"plenary.nvim",
	"nvim-nio",
	"neotest",
}) do
	local lua_path = deps_dir .. "/" .. dep .. "/lua/?.lua"
	local lua_init_path = deps_dir .. "/" .. dep .. "/lua/?/init.lua"
	package.path = package.path .. ";" .. lua_path .. ";" .. lua_init_path
end

-- Add neotest-java source
package.path = package.path .. ";" .. "/project/lua/?.lua" .. ";" .. "/project/lua/?/init.lua"

-- Basic settings
vim.opt.number = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

-- Register neotest-java adapter
require("neotest").setup({
	adapters = {
		require("neotest-java"),
	},
})

vim.notify = function(msg, level, opts)
	vim.print({ msg = msg, level = level })
end
