local Path = require("neotest-java.model.path")
local nio = require("nio")

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

--- @param cwd neotest-java.Path
--- @return vim.lsp.Client
local client_provider = function(cwd)
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
end

return client_provider
