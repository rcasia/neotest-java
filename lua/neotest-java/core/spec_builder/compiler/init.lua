---@class NeotestJavaCompiler.Opts
---@field base_dir neotest-java.Path
---@field classpath_file_dir neotest-java.Path
---@field compile_mode "full" | "incremental"

--- Interface for Java compilers
---@class NeotestJavaCompiler
---@field compile fun(opts: NeotestJavaCompiler.Opts): string classpath_file_arg
local NeotestJavaCompiler = {}

---@type table<string, NeotestJavaCompiler>
local compilers = {
	jdtls = require("neotest-java.core.spec_builder.compiler.jdtls"),
	lsp = require("neotest-java.core.spec_builder.compiler.native_lsp_compiler"),
}

return compilers
