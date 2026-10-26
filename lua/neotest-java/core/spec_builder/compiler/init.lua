local nio = require("nio")
local ClientProvider = require("neotest-java.core.spec_builder.compiler.client_provider")
local LanguageServer = require("neotest-java.core.language_server")
local LspCompiler = require("neotest-java.core.spec_builder.compiler.lsp_compiler")

---@class NeotestJavaCompiler.Opts
---@field base_dir neotest-java.Path
---@field compile_mode "full" | "incremental"

--- Interface for Java compilers
---@class NeotestJavaCompiler
---@field compile fun(opts: NeotestJavaCompiler.Opts): string classpath_file_arg

local client_provider = ClientProvider({
	get_clients = function(opts)
		return vim.lsp.get_clients(opts)
	end,
	globpath = nio.fn.globpath,
	bufadd = vim.fn.bufadd,
	bufload = vim.fn.bufload,
	sleep = function(ms)
		vim.wait(ms, function()
			return false
		end)
	end,
	hrtime = function()
		return vim.uv.hrtime()
	end,
})

--- Single jdtls gateway shared by all delegates: swapping servers in the
--- future means building a different gateway here, not touching callers.
local language_server = LanguageServer.new({ client_provider = client_provider })

---@class neotest-java.Compilers
---@field language_server neotest-java.JavaLanguageServer
---@field lsp NeotestJavaCompiler
---@diagnostic disable-next-line: undefined-doc-name
---@field client_provider fun(cwd: neotest-java.Path): vim.lsp.Client

---@type neotest-java.Compilers
local compilers = {
	language_server = language_server,
	lsp = LspCompiler({ language_server = language_server }),
	client_provider = client_provider,
}

return compilers
