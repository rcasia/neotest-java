local logger = require("neotest-java.logger")
local nio = require("nio")

--- @param deps { client_provider: fun(cwd: neotest-java.Path): vim.lsp.Client }
--- @return NeotestJavaCompiler
local function LspCompiler(deps)
	return {
		compile = function(args)
			local client = deps.client_provider(args.base_dir)

			logger.debug(("compilation in %s mode"):format(args.compile_mode))
			nio.run(function(_)
				nio.scheduler()
				client:request(
					"java/buildWorkspace",
					{ forceRebuild = args.compile_mode == "full" },
					function(err, result, ctx)
						if err then
							logger.error("compilation failed: " .. vim.inspect(err))
						end
					end
				)
			end):wait()
			logger.debug("compilation complete!")
		end,
	}
end

return LspCompiler
