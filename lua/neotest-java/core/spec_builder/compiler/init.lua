local client_provider = require("neotest-java.core.spec_builder.compiler.client_provider")
local LspCompiler = require("neotest-java.core.spec_builder.compiler.lsp_compiler")

---@class NeotestJavaCompiler.Opts
---@field base_dir neotest-java.Path
---@field compile_mode "full" | "incremental"

--- Interface for Java compilers
---@class NeotestJavaCompiler
---@field compile fun(opts: NeotestJavaCompiler.Opts): string classpath_file_arg
local NeotestJavaCompiler = {}

---@type table<string, NeotestJavaCompiler>
local compilers = {
	lsp = LspCompiler({ client_provider = client_provider }),
}

return compilers
