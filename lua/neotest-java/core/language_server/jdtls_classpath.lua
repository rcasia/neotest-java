local nio = require("nio")

-- Classpath separator: ";" on Windows, ":" on Unix.
-- Computed once at module load time since the platform doesn't change at runtime.
local DEFAULT_PATH_SEPARATOR = vim.fn.has("win32") == 1 and ";" or ":"

--- @class neotest-java.JdtlsClasspathDeps
--- @field client_provider fun(cwd: neotest-java.Path): vim.lsp.Client
--- @field schedule? fun(fn: fun()) Defaults to vim.schedule. Inject a synchronous pass-through in tests.
--- @field path_separator? string Defaults to ";" on Windows, ":" on Unix. Inject in tests to avoid platform-dependent behavior.

--- @param deps neotest-java.JdtlsClasspathDeps
--- @return { get_classpath: fun(base_dir: neotest-java.Path, additional_classpath_entries?: neotest-java.Path[]): string }
local function JdtlsClasspath(deps)
	deps = deps or {}
	assert(deps.client_provider, "JdtlsClasspath requires a client_provider")
	local schedule = deps.schedule or vim.schedule
	-- Inject path_separator to make tests deterministic across platforms.
	-- Without injection, tests would need to know the platform they're running on.
	local path_separator = deps.path_separator or DEFAULT_PATH_SEPARATOR

	--- @param base_dir neotest-java.Path
	--- @param additional_classpath_entries? neotest-java.Path[]
	--- @return string classpaths joined by the platform separator
	local function get_classpath(base_dir, additional_classpath_entries)
		additional_classpath_entries = additional_classpath_entries or {}

		local base_dir_uri = vim.uri_from_fname(base_dir:to_string())
		local client = deps.client_provider(base_dir)

		---@diagnostic disable-next-line: undefined-field
		local bufnr = vim.tbl_keys(client.attached_buffers)[1]
		local runtime = nio.control.future()
		local test = nio.control.future()

		-- vim.schedule moves the LSP request out of any fast-event context
		-- (nio coroutines run as libuv callbacks) so nvim_buf_is_valid,
		-- called internally by client:request, is safe to invoke. Mirrors
		-- the fix applied to command/binaries.lua in 7cdd189.
		schedule(function()
			---@diagnostic disable-next-line: undefined-field
			client:request("workspace/executeCommand", {
				command = "java.project.getClasspaths",
				arguments = { base_dir_uri, vim.json.encode({ scope = "runtime" }) },
			}, function(err, result)
				if err then
					runtime.set_error(err)
				else
					runtime.set(result.classpaths)
				end
			end, bufnr)

			---@diagnostic disable-next-line: undefined-field
			client:request("workspace/executeCommand", {
				command = "java.project.getClasspaths",
				arguments = { base_dir_uri, vim.json.encode({ scope = "test" }) },
			}, function(err, result)
				if err then
					test.set_error(err)
				else
					test.set(result.classpaths)
				end
			end, bufnr)
		end)

		local additional_classpath_entries_strings = vim
			--
			.iter(additional_classpath_entries)
			--- @param path neotest-java.Path
			:map(function(path)
				return path:to_string()
			end)
			:totable()

		return vim.iter({
			runtime.wait(),
			test.wait(),
			additional_classpath_entries_strings,
		})
			:flatten()
			:join(path_separator)
	end

	return {
		get_classpath = get_classpath,
	}
end

return JdtlsClasspath
