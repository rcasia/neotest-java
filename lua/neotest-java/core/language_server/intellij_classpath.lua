local nio = require("nio")
local Classpath = require("neotest-java.model.classpath")
local resolve_document_uri = require("neotest-java.core.language_server.document_uri")

-- Classpath separator: ";" on Windows, ":" on Unix.
local DEFAULT_PATH_SEPARATOR = vim.fn.has("win32") == 1 and ";" or ":"

--- @class neotest-java.IntellijClasspathDeps
--- @field client_provider fun(cwd: neotest-java.Path): vim.lsp.Client
--- @field schedule? fun(fn: fun()) Defaults to vim.schedule. Inject a synchronous pass-through in tests.
--- @field path_separator? string Defaults to ";" on Windows, ":" on Unix. Inject in tests to avoid platform-dependent behavior.
--- @field globpath? fun(dir: string, pattern: string, nosuf: boolean, list: boolean): string[]

--- Resolves the complete execution classpath via IntelliJ LSP.
---
--- Architectural details:
--- IntelliJ LSP provides a single command `intellij.java.resolveLaunch` which, when invoked
--- with a representative test document URI, computes the full runtime classpath and modulepath
--- needed to run test code (including `target/test-classes` and test dependencies like JUnit).
--- Both `classpath` and `modulePath` arrays are combined alongside any caller-supplied additional
--- classpath entries into a single `Classpath` value object.
---
--- @param deps neotest-java.IntellijClasspathDeps
--- @return { get_classpath: fun(base_dir: neotest-java.Path, additional_classpath_entries?: neotest-java.Path[]): neotest-java.Classpath }
local function IntellijClasspath(deps)
	deps = deps or {}
	assert(deps.client_provider, "IntellijClasspath requires a client_provider")
	local schedule = deps.schedule or vim.schedule
	local path_separator = deps.path_separator or DEFAULT_PATH_SEPARATOR

	--- @param base_dir neotest-java.Path
	--- @param additional_classpath_entries? neotest-java.Path[]
	--- @return neotest-java.Classpath
	local function get_classpath(base_dir, additional_classpath_entries)
		additional_classpath_entries = additional_classpath_entries or {}

		local doc_uri = resolve_document_uri(base_dir, deps.globpath)
		local client = deps.client_provider(base_dir)

		local future = nio.control.future()

		schedule(function()
			---@diagnostic disable-next-line: undefined-field
			client:request("workspace/executeCommand", {
				command = "intellij.java.resolveLaunch",
				arguments = { { uri = doc_uri } },
			}, function(err, result)
				if err then
					future.set_error(err)
				else
					future.set(result or {})
				end
			end)
		end)

		local res = future.wait()
		local cp_list = res.classpath or {}
		local mp_list = res.modulePath or {}

		local additional_strings = vim.iter(additional_classpath_entries)
			--- @param path neotest-java.Path
			:map(function(path)
				return path:to_string()
			end)
			:totable()

		local entries = vim.iter({
			cp_list,
			mp_list,
			additional_strings,
		})
			:flatten()
			:totable()

		return Classpath(entries, { separator = path_separator })
	end

	return {
		get_classpath = get_classpath,
	}
end

return IntellijClasspath
