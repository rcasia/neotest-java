local logger = require("neotest-java.logger")
local nio = require("nio")
local Path = require("neotest-java.util.path")

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

--- @param dir neotest-java.Path
--- @return neotest-java.Path
local function find_any_java_file(dir)
	return Path(
		assert(
			vim.iter(nio.fn.globpath(dir.to_string(), Path("**/*.java").to_string(), false, true)):next(),
			"No Java file found in the current directory."
		)
	)
end

--- @param path neotest-java.Path
--- @return number bufnr
local function preload_file_for_lsp(path)
	local buf = vim.fn.bufadd(path.to_string()) -- allocates buffer ID
	vim.fn.bufload(path.to_string()) -- preload lines

	return buf
end

local DEFAULT_DEPENDENCIES = {
	--- @param cwd neotest-java.Path
	--- @return vim.lsp.Client
	client_provider = function(cwd)
		local client = get_client()

		if not client then
			local any_java_file = find_any_java_file(cwd)
			local bufnr = preload_file_for_lsp(any_java_file)

			assert(
				vim.wait(10000, function()
					client = get_client(bufnr)
					return not not client and not not client.initialized
				end, 1000),
				"jdtls client not started in time"
			)
		end

		return client
	end,
}

local lsp_compiler = {
	--- @param args { base_dir: neotest-java.Path, compile_mode: "full" | "incremental", dependencies?: table, dependencies?: { client_provider: fun(): vim.lsp.Client } }
	compile = function(args)
		local deps = vim.tbl_extend("force", DEFAULT_DEPENDENCIES, args.dependencies or {})
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
				end,
				vim.api.nvim_get_current_buf()
			)
		end):wait()
		logger.debug("compilation complete!")
	end,
}

---@type NeotestJavaCompiler
return lsp_compiler
