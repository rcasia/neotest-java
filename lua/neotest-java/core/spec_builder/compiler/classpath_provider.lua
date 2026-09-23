--- @class neotest-java.ClasspathProvider
--- @field get_classpath async fun(base_dir: neotest-java.Path, additional_classpath_entries?: neotest-java.Path[]): string classpaths joined by ":"

--- @class neotest-java.ClasspathProviderDeps
--- @field language_server? neotest-java.JavaLanguageServer Single seam for language-server interaction. One of language_server / client_provider is required.
--- @field client_provider? fun(cwd: neotest-java.Path): vim.lsp.Client Deprecated: prefer language_server. When given, a default jdtls gateway is built around it.
--- @field schedule? fun(fn: fun()) Only used with the deprecated client_provider fallback.
--- @field path_separator? string Only used with the deprecated client_provider fallback.

--- @param deps neotest-java.ClasspathProviderDeps
--- @return neotest-java.ClasspathProvider
local function ClasspathProvider(deps)
	deps = deps or {}
	--- @type neotest-java.JavaLanguageServer
	local language_server = deps.language_server
	if not language_server then
		local JdtlsClasspath = require("neotest-java.core.language_server.jdtls_classpath")
		local classpath = JdtlsClasspath({
			client_provider = assert(
				deps.client_provider,
				"ClasspathProvider requires language_server or client_provider"
			),
			schedule = deps.schedule,
			path_separator = deps.path_separator,
		})
		---@diagnostic disable-next-line: missing-fields
		language_server = { get_classpath = classpath.get_classpath }
	end
	---@cast language_server neotest-java.JavaLanguageServer
	return {
		get_classpath = language_server.get_classpath,
	}
end

return ClasspathProvider
