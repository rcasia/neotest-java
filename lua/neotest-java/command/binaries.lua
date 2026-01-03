local Path = require("neotest-java.model.path")

local logger = require("neotest-java.logger")

--- @class neotest-java.LspBinaries
--- @field java fun(cwd: neotest-java.Path): neotest-java.Path

--- @param deps { client_provider: fun(cwd: neotest-java.Path): vim.lsp.Client }
--- @return neotest-java.LspBinaries
local Binaries = function(deps)
	return {

		--- @param cwd neotest-java.Path
		java = function(cwd)
			local client = deps.client_provider(cwd)

			logger.debug("Resolving Java binary via JDTLS for cwd: " .. cwd:to_string())

			local cmd = {

				command = "java.project.getSettings",
				arguments = { vim.uri_from_fname(cwd:to_string()), { "org.eclipse.jdt.ls.core.vm.location" } },
			}
			local res = client:request_sync("workspace/executeCommand", cmd)
			assert(res, "No response from lsp server when getting Java home.")
			assert(not res.err, "Error while getting Java home from lsp server: " .. vim.inspect(res.err))

			local jdtls_java_home = res.result["org.eclipse.jdt.ls.core.vm.location"]

			return Path(jdtls_java_home):append("/bin/java")
		end,
	}
end

return Binaries
