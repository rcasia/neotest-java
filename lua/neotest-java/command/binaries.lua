local Path = require("neotest-java.model.path")

local logger = require("neotest-java.logger")
local nio = require("nio")

--- @class neotest-java.LspBinaries
--- @field java fun(cwd: neotest-java.Path): neotest-java.Path
--- @field javap fun(cwd: neotest-java.Path): neotest-java.Path

--- @param deps { client_provider: fun(cwd: neotest-java.Path): vim.lsp.Client }
--- @return neotest-java.LspBinaries
local Binaries = function(deps)
	local get_java_home = function(cwd)
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

		return res["org.eclipse.jdt.ls.core.vm.location"]
	end

	return {

		--- @param cwd neotest-java.Path
		java = function(cwd)
			return Path(get_java_home(cwd)):append("/bin/java")
		end,

		--- @param cwd neotest-java.Path
		javap = function(cwd)
			return Path(get_java_home(cwd)):append("/bin/javap")
		end,
	}
end

return Binaries
