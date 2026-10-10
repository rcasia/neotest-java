local Path = require("neotest-java.model.path")

--- @class neotest-java.ClientProviderDeps
---@diagnostic disable-next-line: undefined-doc-name
--- @field get_clients fun(opts: table): vim.lsp.Client[]
--- @field globpath fun(dir: string, pattern: string, nosuf: boolean, list: boolean): string[]
--- @field bufadd fun(path: string): number
--- @field bufload fun(path: string)
--- @field sleep fun(ms: number)
--- @field hrtime fun(): number
--- @field client_name? string
--- @field client_names? string[]

--- @param deps neotest-java.ClientProviderDeps
---@diagnostic disable-next-line: undefined-doc-name
--- @return fun(cwd: neotest-java.Path): vim.lsp.Client
local function ClientProvider(deps)
	local client
	local client_names = deps.client_names
		or (deps.client_name and { deps.client_name })
		or { "intellij", "jdtls" }

	--- @param dir neotest-java.Path
	--- @return neotest-java.Path
	local function find_any_java_file(dir)
		return Path(
			assert(
				vim.iter(deps.globpath(dir:to_string(), Path("**/*.java"):to_string(), false, true)):next(),
				"No Java file found in the directory." .. dir:to_string()
			)
		)
	end

	--- @param path neotest-java.Path
	--- @return number bufnr
	local function preload_file_for_lsp(path)
		local buf = deps.bufadd(path:to_string())
		deps.bufload(path:to_string())
		return buf
	end

	local function wait(timeout_ms, condition, interval_ms)
		local start_time = deps.hrtime() / 1e6
		while true do
			if condition() then
				return true
			end

			local current_time = deps.hrtime() / 1e6
			if (current_time - start_time) > timeout_ms then
				return false
			end

			deps.sleep(interval_ms)
		end
	end

	--- @param cwd neotest-java.Path
	---@diagnostic disable-next-line: undefined-doc-name
	--- @return vim.lsp.Client
	return function(cwd)
		if client and client.initialized then
			return client
		end

		for _, name in ipairs(client_names) do
			client = deps.get_clients({ name = name })[1]
			if client and client.initialized then
				return client
			end
		end

		local any_java_file = find_any_java_file(cwd)
		local bufnr = preload_file_for_lsp(any_java_file)

		assert(
			wait(10000, function()
				for _, name in ipairs(client_names) do
					client = deps.get_clients({ name = name, bufnr = bufnr })[1]
					---@diagnostic disable-next-line: undefined-field
					if client and client.initialized then
						return true
					end
				end
				return false
			end, 1000),
			table.concat(client_names, " or ") .. " client not started in time"
		)

		return client
	end
end

return ClientProvider
