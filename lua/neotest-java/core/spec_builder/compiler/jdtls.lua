local logger = require("neotest-java.logger")
local nio = require("nio")
local _jdtls = require("neotest-java.command.jdtls")
local scan = require("plenary.scandir")

--- @param bufnr number | nil
--- @return vim.lsp.Client
local function get_client(bufnr)
	local client_future = nio.control.future()
	nio.run(function()
		local clients = vim.lsp.get_clients({ name = "jdtls", bufnr = bufnr })
		client_future.set(clients and clients[1])
	end)
	return client_future:wait()
end

--- @param dir string
--- @return string | nil
local function find_any_java_file(dir)
	return assert(
		vim.iter(nio.fn.globpath(dir or ".", "**/*.java", false, true)):next(),
		"No Java file found in the current directory."
	)
end

--- @param path string
--- @return number bufnr
local function preload_file_for_lsp(path)
	assert(path, "path cannot be nil")
	local buf = vim.fn.bufadd(path) -- allocates buffer ID
	vim.fn.bufload(path) -- preload lines

	return buf
end

---@type NeotestJavaCompiler
local jdtls_compiler = {
	compile = function(args)
		-- check there is an active java client
		local client = get_client()
		local bufnr
		if not client then
			local any_java_file = assert(find_any_java_file(args.cwd), "No Java file found in the current directory.")
			bufnr = preload_file_for_lsp(any_java_file)

			assert(
				vim.wait(10000, function()
					client = get_client(bufnr)
					return not not client and not not client.initialized
				end, 1000),
				"jdtls client not started in time"
			)
		end

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
				end,
				bufnr or vim.api.nvim_get_current_buf()
			)
		end):wait()
		logger.debug("compilation complete!")

		logger.debug("scanning for test resources in " .. args.cwd)
		local resources = scan.scan_dir(args.cwd, {
			only_dirs = true,
			search_pattern = "test/resources$",
		})

		return _jdtls.get_classpath_file_argument(args.classpath_file_dir, resources)
	end,
}

return jdtls_compiler
