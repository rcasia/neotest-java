local nio = require("nio")
local ClientProvider = require("neotest-java.core.spec_builder.compiler.client_provider")
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
	sleep = nio.sleep,
	hrtime = function()
		return vim.uv.hrtime()
	end,
})

---@type table<string, NeotestJavaCompiler>
local compilers = {
	lsp = LspCompiler({ client_provider = client_provider }),
	client_provider = client_provider,
}

return compilers
