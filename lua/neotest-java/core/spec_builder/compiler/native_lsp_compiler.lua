local logger = require("neotest-java.logger")

--- @param deps { client_provider: fun(cwd: neotest-java.Path): vim.lsp.Client }
--- @return NeotestJavaCompiler
local function LspCompiler(deps)
	return {
		compile = function(args)
			local client = deps.client_provider(args.base_dir)

			logger.debug(("compilation in %s mode"):format(args.compile_mode))

			local response = client:request_sync("java/buildWorkspace", { forceRebuild = args.compile_mode == "full" })

			if not response or response.err then
				logger.error("compilation failed: " .. vim.inspect(response))
			end
			logger.debug("compilation complete: " .. vim.inspect(response))
		end,
	}
end

return LspCompiler
