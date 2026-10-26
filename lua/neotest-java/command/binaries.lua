--- @class neotest-java.LspBinaries
--- @field java fun(cwd: neotest-java.Path): neotest-java.Path
--- @field javap fun(cwd: neotest-java.Path): neotest-java.Path

---@diagnostic disable: undefined-doc-name
--- @class neotest-java.BinariesDeps
--- @field language_server? neotest-java.JavaLanguageServer Single seam for language-server interaction. One of language_server / client_provider is required.
--- @field client_provider? fun(cwd: neotest-java.Path): vim.lsp.Client Deprecated: prefer language_server. When given, a default jdtls gateway is built around it.
--- @field is_windows? boolean
--- @field schedule? fun(fn: fun()) Defaults to vim.schedule. Only used with the deprecated client_provider fallback. Inject a synchronous pass-through in tests.

--- @param deps neotest-java.BinariesDeps
--- @return neotest-java.LspBinaries
local Binaries = function(deps)
	deps = deps or {}
	-- Default platform detection if not provided
	local is_windows = deps.is_windows
	if is_windows == nil then
		is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
	end

	--- @type neotest-java.JavaLanguageServer
	local language_server = deps.language_server
	if not language_server then
		local JdtlsJavaHome = require("neotest-java.core.language_server.jdtls_java_home")
		local java_home = JdtlsJavaHome({
			client_provider = assert(deps.client_provider, "Binaries requires language_server or client_provider"),
			schedule = deps.schedule,
		})
		---@diagnostic disable-next-line: missing-fields
		language_server = { get_java_home = java_home.get_java_home }
	end
	---@cast language_server neotest-java.JavaLanguageServer

	return {

		--- @param cwd neotest-java.Path
		java = function(cwd)
			local exe_ext = is_windows and ".exe" or ""
			return language_server.get_java_home(cwd):append("bin/java" .. exe_ext)
		end,

		--- @param cwd neotest-java.Path
		javap = function(cwd)
			local exe_ext = is_windows and ".exe" or ""
			return language_server.get_java_home(cwd):append("bin/javap" .. exe_ext)
		end,
	}
end

return Binaries
