---@diagnostic disable-next-line: undefined-doc-name
--- @class neotest-java.LspCompilerDeps
--- @field language_server? neotest-java.JavaLanguageServer Single seam for language-server interaction. One of language_server / client_provider is required.
--- @field client_provider? fun(cwd: neotest-java.Path): vim.lsp.Client Deprecated: prefer language_server. When given, a default jdtls gateway is built around it.

--- @param deps neotest-java.LspCompilerDeps
--- @return NeotestJavaCompiler
local function LspCompiler(deps)
	deps = deps or {}
	--- @type neotest-java.JavaLanguageServer
	local language_server = deps.language_server
	if not language_server then
		local JdtlsCompile = require("neotest-java.core.language_server.jdtls_compile")
		local compiler = JdtlsCompile({
			client_provider = assert(deps.client_provider, "LspCompiler requires language_server or client_provider"),
		})
		---@diagnostic disable-next-line: missing-fields
		language_server = { compile = compiler.compile }
	end
	---@cast language_server neotest-java.JavaLanguageServer
	return {
		compile = language_server.compile,
	}
end

return LspCompiler
