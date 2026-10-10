local logger = require("neotest-java.logger")
local nio = require("nio")
local resolve_document_uri = require("neotest-java.core.language_server.document_uri")

---@diagnostic disable-next-line: undefined-doc-name
--- @class neotest-java.IntellijCompileDeps
--- @field client_provider fun(cwd: neotest-java.Path): vim.lsp.Client
--- @field schedule? fun(fn: fun()) Defaults to vim.schedule. Inject a synchronous pass-through in tests.
--- @field system? fun(cmd: string[], opts?: table): table Injectable for testing vim.system.
--- @field globpath? fun(dir: string, pattern: string, nosuf: boolean, list: boolean): string[]

--- Compiles test sources via the build command resolved by IntelliJ LSP.
---
--- Architectural details:
--- Unlike Eclipse JDTLS which compiles directly within its language server process,
--- IntelliJ LSP delegates compilation to the project's native build tool (Maven/Gradle).
--- Calling `intellij.java.resolveBuildCommand` with the test document URI yields the
--- appropriate CLI invocation (e.g. `mvnw test-compile` or `gradle testClasses`).
--- This command is executed using `vim.system`, waiting for completion if running
--- inside an active coroutine (via `coroutine.running()`).
---
--- @param deps neotest-java.IntellijCompileDeps
--- @return { compile: fun(opts: { base_dir: neotest-java.Path, compile_mode: "full" | "incremental" }) }
local function IntellijCompile(deps)
	deps = deps or {}
	assert(deps.client_provider, "IntellijCompile requires a client_provider")
	local schedule = deps.schedule or vim.schedule
	local run_system = deps.system or vim.system

	--- @param opts { base_dir: neotest-java.Path, compile_mode: "full" | "incremental" }
	local function compile(opts)
		local client = deps.client_provider(opts.base_dir)
		if not client or not client.initialized then
			return
		end

		logger.debug(("IntelliJ LSP compilation in %s mode"):format(opts.compile_mode))

		local target_uri = resolve_document_uri(opts.base_dir, deps.globpath)
		local future = nio.control.future()

		schedule(function()
			--- @diagnostic disable-next-line: undefined-field
			client:request("workspace/executeCommand", {
				command = "intellij.java.resolveBuildCommand",
				arguments = { { uri = target_uri } },
			}, function(err, result)
				if err then
					logger.error("IntelliJ LSP resolveBuildCommand failed: " .. vim.inspect(err))
					future.set(false)
					return
				end

				if result and result.supported ~= false and type(result.command) == "table" and #result.command > 0 then
					logger.debug("Executing build command: " .. table.concat(result.command, " "))
					local spawn_ok, proc = pcall(run_system, result.command, {
						cwd = result.cwd or opts.base_dir:to_string(),
					})
					if not spawn_ok then
						logger.error("Failed to spawn build command: " .. tostring(proc))
						future.set(false)
						return
					end

					local completed = proc:wait()
					if completed.code == 0 then
						logger.debug("IntelliJ LSP build command succeeded")
					else
						logger.warn(("IntelliJ LSP build command failed with exit code %d"):format(completed.code))
					end
					future.set(completed.code == 0)
				elseif result and result.reason then
					logger.warn("IntelliJ LSP build skipped: " .. tostring(result.reason))
					future.set(true)
				else
					future.set(true)
				end
			end)
		end)

		-- Only wait when inside a coroutine (e.g. nio async task) to avoid
		-- attempting to yield across C-call boundaries.
		if coroutine.running() then
			future.wait()
		end

		logger.debug("compilation complete!")
	end

	return {
		compile = compile,
	}
end

return IntellijCompile
