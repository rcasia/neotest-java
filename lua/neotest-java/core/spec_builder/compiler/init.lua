local nio = require("nio")

local ClientProvider = require("neotest-java.core.spec_builder.compiler.client_provider")
local LspCompiler = require("neotest-java.core.spec_builder.compiler.lsp_compiler")

local client_provider = ClientProvider({
	get_clients = function(opts)
		return vim.lsp.get_clients(opts)
	end,
	globpath = function(dir, pattern, nosuf, list)
		return nio.fn.globpath(dir, pattern, nosuf, list)
	end,
	bufadd = function(path)
		return vim.fn.bufadd(path)
	end,
	bufload = function(path)
		vim.fn.bufload(path)
	end,
	set_buf_filetype = function(bufnr)
		-- Run inside the buffer's context so that nvim-jdtls's FileType
		-- autocommand sees the correct buffer (and its root path) when it
		-- calls start_or_attach.  Without nvim_buf_call the current buffer
		-- is unrelated and jdtls silently attaches to the wrong module.
		vim.api.nvim_buf_call(bufnr, function()
			vim.api.nvim_set_option_value("filetype", "java", { buf = 0 })
		end)
	end,
	hrtime = function()
		return vim.uv.hrtime() / 1e6
	end,
	sleep = function(ms)
		nio.sleep(ms)
	end,
})

---@class NeotestJavaCompiler.Opts
---@field base_dir neotest-java.Path
---@field compile_mode "full" | "incremental"

--- Interface for Java compilers
---@class NeotestJavaCompiler
---@field compile fun(opts: NeotestJavaCompiler.Opts): string classpath_file_arg

---@type table<string, NeotestJavaCompiler>
local compilers = {
	lsp = LspCompiler({ client_provider = client_provider }),
	client_provider = client_provider,
}

return compilers
