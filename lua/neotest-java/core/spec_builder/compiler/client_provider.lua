local Path = require("neotest-java.model.path")
local nio = require("nio")

--- @class neotest-java.ClientProvider.Deps
--- @field get_clients? fun(opts: table): vim.lsp.Client[]
--- @field buf_add? fun(path: string): number
--- @field buf_load? fun(path: string)
--- @field hrtime? fun(): number  returns current time in milliseconds
--- @field globpath? fun(path: string, pattern: string, nosuf: boolean, list: boolean): string[]

--- @param deps? neotest-java.ClientProvider.Deps
--- @return fun(cwd: neotest-java.Path): vim.lsp.Client
local ClientProvider = function(deps)
	deps = deps or {}
	local _get_clients = deps.get_clients or function(opts)
		return vim.lsp.get_clients(opts)
	end
	local _buf_add = deps.buf_add or vim.fn.bufadd
	local _buf_load = deps.buf_load or vim.fn.bufload
	local _hrtime = deps.hrtime or function()
		return vim.uv.hrtime() / 1e6
	end
	local _globpath = deps.globpath or nio.fn.globpath

	--- @param bufnr number | nil
	--- @return vim.lsp.Client
	local function get_client(bufnr)
		local client_future = nio.control.future()
		nio.run(function()
			local clients = _get_clients({ name = "jdtls", bufnr = bufnr })
			client_future.set(clients and clients[1])
		end)
		return client_future:wait()
	end

	--- @param dir neotest-java.Path
	--- @return neotest-java.Path
	local function find_any_java_file(dir)
		return Path(
			assert(
				vim.iter(_globpath(dir:to_string(), Path("**/*.java"):to_string(), false, true)):next(),
				"No Java file found in the directory." .. dir:to_string()
			)
		)
	end

	--- @param path neotest-java.Path
	--- @return number bufnr
	local function preload_file_for_lsp(path)
		local buf = _buf_add(path:to_string())
		_buf_load(path:to_string())
		return buf
	end

	local function wait(timeout_ms, condition, interval_ms)
		local start_time = _hrtime()
		while true do
			if condition() then
				return true
			end

			local current_time = _hrtime()
			if (current_time - start_time) > timeout_ms then
				return false
			end

			nio.sleep(interval_ms)
		end
	end

	local cached_client = nil

	--- @param cwd neotest-java.Path
	--- @return vim.lsp.Client
	return function(cwd)
		if cached_client and cached_client.initialized then
			return cached_client
		end
		cached_client = get_client()

		if not cached_client then
			local any_java_file = find_any_java_file(cwd)
			local bufnr = preload_file_for_lsp(any_java_file)

			assert(
				wait(10000, function()
					cached_client = get_client(bufnr)
					return not not cached_client and not not cached_client.initialized
				end, 1000),
				"jdtls client not started in time"
			)
		end

		return cached_client
	end
end

return ClientProvider
