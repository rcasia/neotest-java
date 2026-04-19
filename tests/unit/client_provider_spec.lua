local Path = require("neotest-java.model.path")
local assertions = require("tests.assertions")
local eq = assertions.eq

local ClientProvider = require("neotest-java.core.spec_builder.compiler.client_provider")

--- Build a minimal jdtls client stub.
--- @param root_dir? string   Supply the module root so root_dir matching works.
local function make_client(root_dir)
	local c = { initialized = true, attached_buffers = {} }
	if root_dir then
		c.config = { root_dir = root_dir }
	end
	return c
end

describe("ClientProvider", function()
	-- Slice 1: caches the client per cwd — jdtls is not queried on subsequent calls
	it("returns the cached client on repeated calls for the same cwd", function()
		local cwd = Path("/project/module-a")
		local client = make_client("/project/module-a")
		local query_count = 0

		local provider = ClientProvider({
			get_clients = function()
				query_count = query_count + 1
				return { client }
			end,
		})

		provider(cwd)
		provider(cwd)
		provider(cwd)

		eq(1, query_count)
	end)

	-- Slice 2: the original bug — module A's cached client must not be returned for module B
	it("does not reuse module A's cached client when asked for module B", function()
		local cwd_a = Path("/project/module-a")
		local cwd_b = Path("/project/module-b")
		local client_a = make_client("/project/module-a")
		local client_b = make_client("/project/module-b")
		local query_count = 0

		local provider = ClientProvider({
			get_clients = function()
				query_count = query_count + 1
				if query_count == 1 then
					return { client_a }
				end
				return { client_b }
			end,
		})

		local result_a = provider(cwd_a)
		local result_b = provider(cwd_b)

		eq(client_a, result_a)
		eq(client_b, result_b)
		-- clients must be distinct — the bug was that result_b == client_a
		assert(result_a ~= result_b, "Expected different clients for different modules")
	end)

	-- Slice 3: selects the client whose root_dir covers cwd when multiple clients exist
	it("selects the client whose root_dir covers cwd over others", function()
		local cwd = Path("/project/module-b/src/test/java/com/example")
		local client_a = { initialized = true, config = { root_dir = "/project/module-a" } }
		local client_b = { initialized = true, config = { root_dir = "/project/module-b" } }

		local provider = ClientProvider({
			-- client_a is first in the list but must NOT be selected
			get_clients = function()
				return { client_a, client_b }
			end,
		})

		eq(client_b, provider(cwd))
	end)
end)
