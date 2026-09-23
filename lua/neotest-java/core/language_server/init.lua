local JdtlsJavaHome = require("neotest-java.core.language_server.jdtls_java_home")
local JdtlsClasspath = require("neotest-java.core.language_server.jdtls_classpath")
local JdtlsCompile = require("neotest-java.core.language_server.jdtls_compile")

--- Single seam for all Java language-server interaction.
--- A future server (e.g. the IntelliJ LSP from issue #314) replaces this
--- whole table with its own three methods; callers never change.
--- @class neotest-java.JavaLanguageServer
--- @field get_java_home fun(cwd: neotest-java.Path): neotest-java.Path
--- @field get_classpath fun(base_dir: neotest-java.Path, additional_classpath_entries?: neotest-java.Path[]): string classpaths joined by the platform separator
--- @field compile fun(opts: { base_dir: neotest-java.Path, compile_mode: "full" | "incremental" })

--- @class neotest-java.JavaLanguageServerDeps
--- @field client_provider fun(cwd: neotest-java.Path): vim.lsp.Client Shared jdtls client provider (see compiler/client_provider.lua).
--- @field schedule? fun(fn: fun()) Defaults to vim.schedule. Inject a synchronous pass-through in tests.
--- @field path_separator? string Defaults to ";" on Windows, ":" on Unix. Inject in tests to avoid platform-dependent behavior.

--- @param deps neotest-java.JavaLanguageServerDeps
--- @return neotest-java.JavaLanguageServer
local function JavaLanguageServer(deps)
	deps = deps or {}
	assert(deps.client_provider, "JavaLanguageServer requires a client_provider")

	local java_home = JdtlsJavaHome({
		client_provider = deps.client_provider,
		schedule = deps.schedule,
	})
	local classpath = JdtlsClasspath({
		client_provider = deps.client_provider,
		schedule = deps.schedule,
		path_separator = deps.path_separator,
	})
	local compiler = JdtlsCompile({
		client_provider = deps.client_provider,
		schedule = deps.schedule,
	})

	return {
		get_java_home = java_home.get_java_home,
		get_classpath = classpath.get_classpath,
		compile = compiler.compile,
	}
end

return {
	new = JavaLanguageServer,
}
