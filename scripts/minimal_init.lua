-- scripts/minimal_init.lua
-- Headless testing with mini.test, no user config loaded.

local DEPENDENCIES_DIR = "./.dependencies"

-- Speed up startup
for _, p in ipairs({
	"gzip",
	"zip",
	"zipPlugin",
	"tar",
	"tarPlugin",
	"vimball",
	"vimballPlugin",
	"2html_plugin",
	"matchit",
	"matchparen",
	"netrw",
	"netrwPlugin",
	"netrwSettings",
	"netrwFileHandlers",
	"rrhelper",
	"spellfile_plugin",
	"shada_plugin",
}) do
	vim.g["loaded_" .. p] = 1
end

vim.opt.shortmess:append("I")
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- ─────────────────────────────────────────────────────────────
-- Ensure dependencies exist (auto-clone if missing)
-- ─────────────────────────────────────────────────────────────
local function ensure_repo(path, url)
	if vim.fn.isdirectory(path) == 0 then
		vim.fn.mkdir(path, "p")
		vim.fn.system({ "git", "clone", "--depth", "1", url, path })
	end
end

ensure_repo(DEPENDENCIES_DIR .. "/mini.nvim", "https://github.com/echasnovski/mini.nvim")
ensure_repo(DEPENDENCIES_DIR .. "/nvim-nio", "https://github.com/nvim-neotest/nvim-nio")
ensure_repo(DEPENDENCIES_DIR .. "/neotest", "https://github.com/nvim-neotest/neotest")
ensure_repo(DEPENDENCIES_DIR .. "/nvim-treesitter", "https://github.com/nvim-treesitter/nvim-treesitter")
ensure_repo(DEPENDENCIES_DIR .. "/plenary.nvim", "https://github.com/nvim-lua/plenary.nvim")

-- ─────────────────────────────────────────────────────────────
-- Runtime path setup (plugin roots, NOT /lua/ subdirectories)
-- ─────────────────────────────────────────────────────────────
vim.opt.runtimepath:append(".")
vim.opt.runtimepath:append(DEPENDENCIES_DIR .. "/mini.nvim")
vim.opt.runtimepath:append(DEPENDENCIES_DIR .. "/nvim-nio")
vim.opt.runtimepath:append(DEPENDENCIES_DIR .. "/neotest")
vim.opt.runtimepath:append(DEPENDENCIES_DIR .. "/nvim-treesitter")
vim.opt.runtimepath:append(DEPENDENCIES_DIR .. "/plenary.nvim")

-- ─────────────────────────────────────────────────────────────
-- Enable mini.test
-- ─────────────────────────────────────────────────────────────

-- Inject luassert as global 'assert' so tests can use assert.are.same etc.
_G.assert = require("luassert")

require("mini.test").setup({
	collect = {
		emulate_busted = true,
		find_files = function()
			return vim.fn.globpath("tests/unit", "**/*_spec.lua", true, true)
		end,
	},
	execute = {
		reporter = require("mini.test").gen_reporter.stdout(),
		stop_on_error = false,
	},
})

-- ─────────────────────────────────────────────────────────────
-- Patch nio.tests to work correctly with mini.test in headless mode
-- ─────────────────────────────────────────────────────────────
-- Problem: nio.tests.with_timeout uses vim.wait(..., fast_only=false), which
-- processes ALL vim.schedule callbacks while waiting — including
-- mini.test's reporter.finish callback that calls 0cquit, killing Neovim
-- before the async test completes.
--
-- Fix: replace the nio.tests metatable __index to use fast_only=true.
-- This allows libuv I/O and timer events (used by nio.uv.* and nio.sleep)
-- to fire, while blocking vim.schedule callbacks (like reporter.finish).
do
	local nio_tests = require("nio").tests
	local tasks = require("nio.tasks")

	local function patched_with_timeout(func, timeout)
		local success, err, results
		return function()
			local task = tasks.run(func, function(success_, ...)
				success = success_
				if not success_ then
					err = ...
				else
					results = { ... }
				end
			end)
			vim.wait(timeout or 2000, function()
				return success ~= nil
			end, 10, true) -- fast_only = true: don't process vim.schedule callbacks
			if success == nil then
				error(string.format("Test task timed out\n%s", task.trace()))
			elseif not success then
				error(string.format("Test task failed with message:\n%s", err))
			end
			return unpack(results or {})
		end
	end

	local mt = getmetatable(nio_tests)
	mt.__index = function(_table, key)
		local hook = getfenv(2)[key]
		if not hook then
			return nil
		end
		if key == "it" then
			return function(name, async_func)
				hook(name, patched_with_timeout(async_func, tonumber(vim.env.PLENARY_TEST_TIMEOUT)))
			end
		elseif key == "before_each" or key == "after_each" then
			return function(async_func)
				hook(patched_with_timeout(async_func))
			end
		end
	end
end

-- ─────────────────────────────────────────────────────────────
-- Patch nio.scheduler to be a no-op in tests
-- ─────────────────────────────────────────────────────────────
-- nio.scheduler() yields to a vim.schedule callback purely to ensure the
-- coroutine is on the main Neovim API thread. All test coroutines already
-- start from a vim.schedule callback (mini.test's H.schedule_case), so
-- they are always in a safe context. Making it a no-op avoids an unnecessary
-- yield that would block on a vim.schedule callback — which fast_only=true
-- does not process.
require("nio").scheduler = function() end
