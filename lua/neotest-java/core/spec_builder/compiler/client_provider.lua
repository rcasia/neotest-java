local logger = require("neotest-java.logger")

--- @class ClientProvider.Deps
--- @field get_clients fun(opts?: {name?: string}): vim.lsp.Client[]

--- @param deps ClientProvider.Deps
--- @return fun(cwd: neotest-java.Path): vim.lsp.Client
local ClientProvider = function(deps)
	--- One cached client per module directory so that switching between modules
	--- always resolves the correct jdtls instance rather than reusing a stale one.
	--- @type table<string, vim.lsp.Client>
	local clients = {}

	--- @param cwd neotest-java.Path
	--- @return vim.lsp.Client
	return function(cwd)
		local key = cwd:to_string()

		if clients[key] and clients[key].initialized then
			return clients[key]
		end

		local all = deps.get_clients({ name = "jdtls" })

		-- Prefer the client whose root_dir covers cwd so that in multimodule
		-- projects (multiple jdtls instances) the correct one is selected.
		for _, c in ipairs(all) do
			if c.initialized and c.config and c.config.root_dir and vim.startswith(key, c.config.root_dir) then
				logger.debug("client_provider: selected by root_dir match: " .. c.config.root_dir)
				clients[key] = c
				return c
			end
		end

		-- Fall back to the first available client. This covers the standard
		-- single-jdtls workspace setup where one server handles all modules.
		clients[key] = assert(all[1], "No jdtls client found for: " .. key)
		return clients[key]
	end
end

return ClientProvider
