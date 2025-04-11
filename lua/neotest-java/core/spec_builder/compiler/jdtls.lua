local logger = require("neotest-java.logger")
local nio = require("nio")
local _jdtls = require("neotest-java.command.jdtls")
local scan = require("plenary.scandir")

---@type NeotestJavaCompiler
local jdtls_compiler = {
	compile = function(args)
		-- check there is an active java client
		local clients = vim.lsp.get_clients({ name = "jdtls" })
		local client = assert(clients and clients[1], "there is no jdtls client attached.")

		logger.debug(("compilation in %s mode"):format(args.compile_mode))
		nio.run(function(_)
			nio.scheduler()
			local bufnr = 0 --TODO: set bufnr to the java file being compiled
			client:request(
				"java/buildWorkspace",
				{ forceRebuild = args.compile_mode == "full" },
				function(err, result, ctx)
					if err then
						logger.error("compilation failed: " .. vim.inspect(err))
					end
				end,
				bufnr
			)
		end):wait()
		logger.debug("compilation complete!")

		local resources = scan.scan_dir(args.cwd, {
			only_dirs = true,
			search_pattern = "test/resources$",
		})

		return _jdtls.get_classpath_file_argument(args.classpath_file_dir, resources)
	end,
}

return jdtls_compiler
