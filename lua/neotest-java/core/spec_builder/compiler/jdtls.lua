local logger = require("neotest-java.logger")
local nio = require("nio")
local _jdtls = require("neotest-java.command.jdtls")
local scan = require("plenary.scandir")

---@type NeotestJavaCompiler
local jdtls_compiler = {
	compile = function(args)
		-- check that required dependencies are present
		local ok_jdtls, jdtls = pcall(require, "jdtls")
		assert(ok_jdtls, "neotest-java requires nvim-jdtls to tests")

		-- check there is an active java client
		local has_jdtls_client = #nio.lsp.get_clients({ name = "jdtls" }) ~= 0
		assert(has_jdtls_client, "there is no jdtls client attached.")

		logger.debug(("compilation in %s mode"):format(args.compile_mode))
		nio.run(function(_)
			nio.scheduler()
			jdtls.compile(args.compile_mode)
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
