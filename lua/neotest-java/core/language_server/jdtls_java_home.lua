local Path = require("neotest-java.model.path")

local logger = require("neotest-java.logger")
local nio = require("nio")

---@diagnostic disable: undefined-doc-name
--- @class neotest-java.JdtlsJavaHomeDeps
--- @field client_provider fun(cwd: neotest-java.Path): vim.lsp.Client
--- @field schedule? fun(fn: fun()) Defaults to vim.schedule. Inject a synchronous pass-through in tests.

--- @param deps neotest-java.JdtlsJavaHomeDeps
--- @return { get_java_home: fun(cwd: neotest-java.Path): neotest-java.Path }
local function JdtlsJavaHome(deps)
	deps = deps or {}
	assert(deps.client_provider, "JdtlsJavaHome requires a client_provider")
	local schedule = deps.schedule or vim.schedule

	local cached_java_homes = {}

	--- @param cwd neotest-java.Path
	--- @return neotest-java.Path
	local function get_java_home(cwd)
		if cached_java_homes[cwd:to_string()] then
			return Path(cached_java_homes[cwd:to_string()])
		end
		local client = deps.client_provider(cwd)

		logger.debug("Resolving Java home via JDTLS for cwd: " .. cwd:to_string())

		local cmd = {
			command = "java.project.getSettings",
			arguments = { vim.uri_from_fname(cwd:to_string()), { "org.eclipse.jdt.ls.core.vm.location" } },
		}
		local result_future = nio.control.future()
		schedule(function()
			---@diagnostic disable-next-line: undefined-field
			client:request("workspace/executeCommand", cmd, function(err, res)
				assert(not err, "Error while getting Java home from lsp server: " .. vim.inspect(err))
				assert(not res.err, "Error while getting Java home from lsp server: " .. vim.inspect(res.err))
				result_future.set(res)
			end)
		end)
		local res = result_future.wait()

		cached_java_homes[cwd:to_string()] = res["org.eclipse.jdt.ls.core.vm.location"]
		return Path(cached_java_homes[cwd:to_string()])
	end

	return {
		get_java_home = get_java_home,
	}
end

return JdtlsJavaHome
