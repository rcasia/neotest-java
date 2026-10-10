local JdtlsJavaHome = require("neotest-java.core.language_server.jdtls_java_home")
local JdtlsClasspath = require("neotest-java.core.language_server.jdtls_classpath")
local JdtlsCompile = require("neotest-java.core.language_server.jdtls_compile")
local IntellijJavaHome = require("neotest-java.core.language_server.intellij_java_home")
local IntellijClasspath = require("neotest-java.core.language_server.intellij_classpath")
local IntellijCompile = require("neotest-java.core.language_server.intellij_compile")

--- Single gateway seam for all Java language-server interactions.
---
--- Architectural details:
--- Provides a unified interface (`JavaLanguageServer`) fronting both Eclipse JDTLS and IntelliJ LSP.
--- Upstream callers (`Binaries`, `ClasspathProvider`, `LspCompiler`) interact solely with this seam,
--- completely decoupled from specific LSP implementations, protocols, and quirks.
---
--- Dispatch mechanism:
--- For each operation, the active client is checked via `client_provider(cwd)`.
---   - If `client.name == "intellij"`, delegates to the IntelliJ resolvers (`intellij_java_home`,
---     `intellij_classpath`, `intellij_compile`).
---   - Otherwise (default / `client.name == "jdtls"`), delegates to the JDTLS resolvers.
---
--- @class neotest-java.JavaLanguageServer
--- @field get_java_home fun(cwd: neotest-java.Path): neotest-java.Path
--- @field get_classpath fun(base_dir: neotest-java.Path, additional_classpath_entries?: neotest-java.Path[]): neotest-java.Classpath | string runtime + test + extra entries, in order. Custom providers may return a plain string; callers coerce via tostring().
--- @field compile fun(opts: { base_dir: neotest-java.Path, compile_mode: "full" | "incremental" })

--- @class neotest-java.JavaLanguageServerDeps
--- @field client_provider fun(cwd: neotest-java.Path): vim.lsp.Client Shared client provider (see compiler/client_provider.lua).
--- @field schedule? fun(fn: fun()) Defaults to vim.schedule. Inject a synchronous pass-through in tests.
--- @field path_separator? string Defaults to ";" on Windows, ":" on Unix. Inject in tests to avoid platform-dependent behavior.
--- @field system? fun(cmd: string[], opts?: table): table Injectable for testing vim.system.
--- @field globpath? fun(dir: string, pattern: string, nosuf: boolean, list: boolean): string[]

--- @param deps neotest-java.JavaLanguageServerDeps
--- @return neotest-java.JavaLanguageServer
local function JavaLanguageServer(deps)
	deps = deps or {}
	assert(deps.client_provider, "JavaLanguageServer requires a client_provider")

	local jdtls = {
		java_home = JdtlsJavaHome({
			client_provider = deps.client_provider,
			schedule = deps.schedule,
		}),
		classpath = JdtlsClasspath({
			client_provider = deps.client_provider,
			schedule = deps.schedule,
			path_separator = deps.path_separator,
		}),
		compiler = JdtlsCompile({
			client_provider = deps.client_provider,
			schedule = deps.schedule,
		}),
	}

	local intellij = {
		java_home = IntellijJavaHome({
			client_provider = deps.client_provider,
			schedule = deps.schedule,
		}),
		classpath = IntellijClasspath({
			client_provider = deps.client_provider,
			schedule = deps.schedule,
			path_separator = deps.path_separator,
			globpath = deps.globpath,
		}),
		compiler = IntellijCompile({
			client_provider = deps.client_provider,
			schedule = deps.schedule,
			system = deps.system,
			globpath = deps.globpath,
		}),
	}

	local function get_backend(cwd)
		local client = deps.client_provider(cwd)
		if client and client.name == "intellij" then
			return {
				get_java_home = intellij.java_home.get_java_home,
				get_classpath = intellij.classpath.get_classpath,
				compile = intellij.compiler.compile,
			}
		end
		return {
			get_java_home = jdtls.java_home.get_java_home,
			get_classpath = jdtls.classpath.get_classpath,
			compile = jdtls.compiler.compile,
		}
	end

	return {
		get_java_home = function(cwd)
			return get_backend(cwd).get_java_home(cwd)
		end,
		get_classpath = function(base_dir, additional_classpath_entries)
			return get_backend(base_dir).get_classpath(base_dir, additional_classpath_entries)
		end,
		compile = function(opts)
			return get_backend(opts.base_dir).compile(opts)
		end,
	}
end

return {
	new = JavaLanguageServer,
	jdtls = JavaLanguageServer,
}
