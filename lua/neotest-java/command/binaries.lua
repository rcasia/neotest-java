local Path = require("neotest-java.model.path")

local logger = require("neotest-java.logger")
local nio = require("nio")

--- @class neotest-java.LspBinaries
--- @field java fun(cwd: neotest-java.Path): neotest-java.Path
--- @field javap fun(cwd: neotest-java.Path): neotest-java.Path

--- @class neotest-java.BinariesDeps
--- @field client_provider fun(cwd: neotest-java.Path): vim.lsp.Client
--- @field is_windows? boolean

--- @param deps neotest-java.BinariesDeps
--- @return neotest-java.LspBinaries
local Binaries = function(deps)
	-- Default platform detection if not provided
	local is_windows = deps.is_windows
	if is_windows == nil then
		is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
	end

	local cached_java_homes = {}
	--- @param cwd neotest-java.Path
	local get_java_home = function(cwd)
		if cached_java_homes[cwd:to_string()] then
			return cached_java_homes[cwd:to_string()]
		end
		local client = deps.client_provider(cwd)

		logger.debug("Resolving Java home via JDTLS for cwd: " .. cwd:to_string())

		local cmd = {

			command = "java.project.getSettings",
			arguments = { vim.uri_from_fname(cwd:to_string()), { "org.eclipse.jdt.ls.core.vm.location" } },
		}
		local result_future = nio.control.future()
		client:request("workspace/executeCommand", cmd, function(err, res)
			assert(not err, "Error while getting Java home from lsp server: " .. vim.inspect(err))

			assert(not res.err, "Error while getting Java home from lsp server: " .. vim.inspect(res.err))
			result_future.set(res)
		end)
		local res = result_future.wait()

		cached_java_homes[cwd:to_string()] = res["org.eclipse.jdt.ls.core.vm.location"]
		return cached_java_homes[cwd:to_string()]
	end

	return {

		--- @param cwd neotest-java.Path
		java = function(cwd)
			local exe_ext = is_windows and ".exe" or ""
			return Path(get_java_home(cwd)):append("bin/java" .. exe_ext)
		end,

		--- @param cwd neotest-java.Path
		javap = function(cwd)
			local exe_ext = is_windows and ".exe" or ""
			return Path(get_java_home(cwd)):append("bin/javap" .. exe_ext)
		end,
	}
end

return Binaries
