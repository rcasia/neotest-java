local Path = require("neotest-java.model.path")
local logger = require("neotest-java.logger")

--- @class ClientProvider.Deps
--- @field get_clients      fun(opts?: {name?: string}): vim.lsp.Client[]
--- @field globpath         fun(dir: string, pattern: string, nosuf: boolean, list: boolean): string[]
--- @field bufadd           fun(path: string): number
--- @field bufload          fun(path: string)
--- @field set_buf_filetype fun(bufnr: number)   -- fires FileType java in bufnr's context to trigger jdtls attachment
--- @field hrtime           fun(): number          -- current time in milliseconds
--- @field sleep            fun(ms: number)

--- @param deps ClientProvider.Deps
--- @return fun(cwd: neotest-java.Path): vim.lsp.Client
local ClientProvider = function(deps)
	--- Finds the jdtls client whose root_dir covers `cwd`.
	--- Returns nil when no match exists (caller should trigger the slow path).
	--- @param cwd neotest-java.Path
	--- @return vim.lsp.Client | nil
	local function get_client(cwd)
		local all = deps.get_clients({ name = "jdtls" })

		logger.debug("client_provider: found " .. #all .. " jdtls client(s)")
		for i, c in ipairs(all) do
			local root = c.config and c.config.root_dir or "<no root_dir>"
			logger.debug(
				"client_provider:   [" .. i .. "] root_dir=" .. root .. " initialized=" .. tostring(c.initialized)
			)
		end

		-- Prefer the client whose root_dir is a prefix of cwd so that in
		-- multimodule projects the correct jdtls instance is chosen.
		-- If no root_dir matches, return nil — never fall back to a wrong-module
		-- client, because that would cause -32001 errors.
		local cwd_str = cwd:to_string()
		for _, c in ipairs(all) do
			if c.initialized and c.config and c.config.root_dir and vim.startswith(cwd_str, c.config.root_dir) then
				logger.debug("client_provider: selected by root_dir match: " .. c.config.root_dir)
				return c
			end
		end

		logger.debug("client_provider: no root_dir match, returning nil to trigger slow path")
		return nil
	end

	--- @param dir neotest-java.Path
	--- @return neotest-java.Path
	local function find_any_java_file(dir)
		return Path(
			assert(
				vim.iter(deps.globpath(dir:to_string(), Path("**/*.java"):to_string(), false, true)):next(),
				"No Java file found in the directory: " .. dir:to_string()
			)
		)
	end

	local function wait(timeout_ms, condition, interval_ms)
		local start_time = deps.hrtime()
		while true do
			if condition() then
				return true
			end
			if (deps.hrtime() - start_time) > timeout_ms then
				return false
			end
			deps.sleep(interval_ms)
		end
	end

	--- One cached client per module directory so that switching between modules
	--- always resolves the correct jdtls instance rather than reusing a stale one.
	--- @type table<string, vim.lsp.Client>
	local clients = {}

	--- @param cwd neotest-java.Path
	--- @return vim.lsp.Client
	return function(cwd)
		local key = cwd:to_string()
		logger.debug("client_provider called for cwd: " .. key)

		if clients[key] and clients[key].initialized then
			return clients[key]
		end

		clients[key] = get_client(cwd)

		if not clients[key] then
			-- No jdtls is up yet: preload a java file from cwd and set its
			-- filetype so that the "FileType java" autocommand fires and jdtls
			-- attaches (or starts) for this module.
			local any_java_file = find_any_java_file(cwd)
			local bufnr = deps.bufadd(any_java_file:to_string())
			deps.bufload(any_java_file:to_string())
			deps.set_buf_filetype(bufnr)

			assert(
				wait(120000, function()
					clients[key] = get_client(cwd)
					return not not clients[key] and not not clients[key].initialized
				end, 1000),
				"jdtls client not started in time for: " .. key
			)
		end

		return clients[key]
	end
end

return ClientProvider
