local jdtls_compiler = require("neotest-java.core.spec_builder.compiler.jdtls")

---@class NeotestJavaCompiler.Opts
---@field cwd string
---@field classpath_file_dir string
---@field compile_mode string

--- Interface for Java compilers
---@class NeotestJavaCompiler
local NeotestJavaCompiler = {}

---@param opts NeotestJavaCompiler.Opts
---@return string classpath_file_arg
function NeotestJavaCompiler.compile(opts) end

---@type table<string, NeotestJavaCompiler>
local compilers = {
	jdtls = jdtls_compiler,
}

return compilers
