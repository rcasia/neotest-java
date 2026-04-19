local Path = require("neotest-java.model.path")
local assertions = require("tests.assertions")
local eq = assertions.eq
local it = require("nio").tests.it

local ClientProvider = require("neotest-java.core.spec_builder.compiler.client_provider")

describe("ClientProvider", function()
	it("returns an initialized jdtls client immediately (fast path)", function()
		-- NOTE: this test intentionally placed first because it verifies the fast
		-- path before any client is cached in a fresh provider instance.
		local mock_client = { initialized = true }

		local provider = ClientProvider({
			get_clients = function(_)
				return { mock_client }
			end,
			globpath = function()
				error("globpath should not be called on fast path")
			end,
			bufadd = function()
				error("bufadd should not be called on fast path")
			end,
			bufload = function()
				error("bufload should not be called on fast path")
			end,
			sleep = function()
				error("sleep should not be called on fast path")
			end,
			hrtime = function()
				return 0
			end,
		})

		local result = provider(Path("/some/project"))
		eq(mock_client, result)
	end)

	it("caches the client and does not call get_clients again", function()
		local call_count = 0
		local mock_client = { initialized = true }

		local provider = ClientProvider({
			get_clients = function(_)
				call_count = call_count + 1
				return { mock_client }
			end,
			globpath = function()
				error("globpath should not be called when client is cached")
			end,
			bufadd = function()
				error("bufadd should not be called when client is cached")
			end,
			bufload = function()
				error("bufload should not be called when client is cached")
			end,
			sleep = function()
				error("sleep should not be called when client is cached")
			end,
			hrtime = function()
				return 0
			end,
		})

		local cwd = Path("/some/project")
		provider(cwd)
		provider(cwd)
		provider(cwd)

		eq(1, call_count)
	end)

	it("preloads a java file and polls until client is ready (slow path)", function()
		local mock_client = { initialized = true }
		local get_clients_call_count = 0
		local bufadd_arg, bufload_arg
		local sleep_count = 0

		local cwd = Path("/some/project")
		local java_file = Path("/some/project/src/Main.java")

		local provider = ClientProvider({
			get_clients = function(_)
				get_clients_call_count = get_clients_call_count + 1
				-- first call (no bufnr): jdtls not running yet
				if get_clients_call_count == 1 then
					return {}
				end
				-- polling calls (with bufnr): ready on 3rd overall call
				if get_clients_call_count >= 3 then
					return { mock_client }
				end
				return {}
			end,
			globpath = function(dir, _, _, list)
				eq(cwd:to_string(), dir)
				eq(true, list)
				return { java_file:to_string() }
			end,
			bufadd = function(path)
				bufadd_arg = path
				return 42
			end,
			bufload = function(path)
				bufload_arg = path
			end,
			sleep = function(_)
				sleep_count = sleep_count + 1
			end,
			hrtime = function()
				return 0
			end,
		})

		local result = provider(cwd)

		eq(mock_client, result)
		eq(java_file:to_string(), bufadd_arg)
		eq(java_file:to_string(), bufload_arg)
		assert(sleep_count >= 1, "expected at least one sleep call during polling")
	end)
end)
