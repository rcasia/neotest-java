local Path = require("neotest-java.model.path")
local logger = require("neotest-java.logger")
local nio = require("nio")

---@diagnostic disable: undefined-doc-name
--- @class neotest-java.IntellijJavaHomeDeps
--- @field client_provider fun(cwd: neotest-java.Path): vim.lsp.Client
--- @field schedule? fun(fn: fun()) Defaults to vim.schedule. Inject a synchronous pass-through in tests.

--- Resolves the JDK home directory for IntelliJ LSP.
---
--- Architectural details:
--- IntelliJ LSP returns `javaExec` pointing to the exact Java binary configured for the project
--- (e.g. `<jdk>/bin/java` on Unix or `<jdk>\bin\java.exe` on Windows).
--- Downstream consumers (`neotest-java.command.binaries`) expect the root JDK directory so they
--- can locate both `bin/java` (for test execution) and `bin/javap` (for method signature disambiguation).
--- Calling `:parent():parent()` traverses from binary -> `bin` directory -> JDK root.
--- Results are cached per directory to avoid redundant LSP roundtrips.
---
--- @param deps neotest-java.IntellijJavaHomeDeps
--- @return { get_java_home: fun(cwd: neotest-java.Path): neotest-java.Path }
local function IntellijJavaHome(deps)
	deps = deps or {}
	assert(deps.client_provider, "IntellijJavaHome requires a client_provider")
	local schedule = deps.schedule or vim.schedule

	local cached_java_homes = {}

	--- @param cwd neotest-java.Path
	--- @return neotest-java.Path
	local function get_java_home(cwd)
		local cwd_str = cwd:to_string()
		if cached_java_homes[cwd_str] then
			return Path(cached_java_homes[cwd_str])
		end

		local client = deps.client_provider(cwd)

		logger.debug("Resolving Java home via IntelliJ LSP for cwd: " .. cwd_str)

		local cmd = {
			command = "intellij.java.resolveLaunch",
			arguments = { { uri = vim.uri_from_fname(cwd_str) } },
		}
		local result_future = nio.control.future()
		schedule(function()
			---@diagnostic disable-next-line: undefined-field
			client:request("workspace/executeCommand", cmd, function(err, res)
				if err then
					result_future.set_error(err)
				else
					result_future.set(res or {})
				end
			end)
		end)

		local ok, res = pcall(function()
			return result_future.wait()
		end)

		local java_home_path = nil
		if ok and res and res.javaExec and res.javaExec ~= "" then
			-- res.javaExec points to <jdk>/bin/java (or java.exe)
			local java_bin = Path(res.javaExec)
			java_home_path = java_bin:parent():parent()
		else
			-- Fallback to JAVA_HOME environment variable or path from java executable
			if vim.env.JAVA_HOME and vim.env.JAVA_HOME ~= "" then
				java_home_path = Path(vim.env.JAVA_HOME)
			else
				local exepath = vim.fn.exepath("java")
				if exepath and exepath ~= "" then
					java_home_path = Path(exepath):parent():parent()
				end
			end
		end

		assert(java_home_path, "Could not determine Java home from IntelliJ LSP or environment for " .. cwd_str)

		cached_java_homes[cwd_str] = java_home_path:to_string()
		return java_home_path
	end

	return {
		get_java_home = get_java_home,
	}
end

return IntellijJavaHome
