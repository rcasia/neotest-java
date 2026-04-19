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
			buf_get_name = function()
				return ""
			end,
			globpath = function()
				error("should not reach slow path")
			end,
			bufadd = function()
				error("should not reach slow path")
			end,
			bufload = function()
				error("should not reach slow path")
			end,
			set_buf_filetype = function()
				error("should not reach slow path")
			end,
			hrtime = function()
				return 0
			end,
			sleep = function() end,
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
				-- First call is for module-a, second for module-b
				if query_count == 1 then
					return { client_a }
				end
				return { client_b }
			end,
			buf_get_name = function()
				return ""
			end,
			globpath = function()
				error("should not reach slow path")
			end,
			bufadd = function()
				error("should not reach slow path")
			end,
			bufload = function()
				error("should not reach slow path")
			end,
			set_buf_filetype = function()
				error("should not reach slow path")
			end,
			hrtime = function()
				return 0
			end,
			sleep = function() end,
		})

		local result_a = provider(cwd_a)
		local result_b = provider(cwd_b)

		eq(client_a, result_a)
		eq(client_b, result_b)
		-- clients must be distinct — the bug was that result_b == client_a
		assert(result_a ~= result_b, "Expected different clients for different modules")
	end)

	-- Slice 4: selects the client whose root_dir covers cwd when multiple clients exist
	it("selects the client whose root_dir covers cwd over others", function()
		local cwd = Path("/project/module-b/src/test/java/com/example")
		local client_a = { initialized = true, attached_buffers = {}, config = { root_dir = "/project/module-a" } }
		local client_b = { initialized = true, attached_buffers = {}, config = { root_dir = "/project/module-b" } }

		local provider = ClientProvider({
			-- client_a is first in the list but must NOT be selected
			get_clients = function()
				return { client_a, client_b }
			end,
			globpath = function()
				error("should not reach slow path")
			end,
			bufadd = function()
				error("should not reach slow path")
			end,
			bufload = function()
				error("should not reach slow path")
			end,
			set_buf_filetype = function()
				error("should not reach slow path")
			end,
			hrtime = function()
				return 0
			end,
			sleep = function() end,
		})

		eq(client_b, provider(cwd))
	end)

	-- Slice 5: the core multimodule bug — wrong-module client must not be returned
	-- When only module-a's jdtls is running and we ask for module-b's cwd,
	-- the slow path must fire (preload + wait) rather than returning module-a's client.
	-- The wait loop must detect the new client via root_dir matching (not bufnr),
	-- because jdtls may not attach to the preloaded buffer at all.
	it("triggers slow path when existing client root_dir does not match cwd", function()
		local cwd = Path("/project/module-b")
		local wrong_client = { initialized = true, config = { root_dir = "/project/module-a" } }
		local right_client = { initialized = true, config = { root_dir = "/project/module-b" } }
		local bufadd_called = false
		local set_ft_bufnr = nil
		local filetype_set = false

		local provider = ClientProvider({
			get_clients = function()
				-- Once set_buf_filetype fires, simulate module-b's jdtls appearing
				if filetype_set then
					return { wrong_client, right_client }
				end
				return { wrong_client }
			end,
			globpath = function()
				return { "/project/module-b/src/Foo.java" }
			end,
			bufadd = function()
				bufadd_called = true
				return 42
			end,
			bufload = function() end,
			set_buf_filetype = function(bufnr)
				set_ft_bufnr = bufnr
				filetype_set = true
			end,
			hrtime = function()
				return 0
			end,
			sleep = function() end,
		})

		local result = provider(cwd)
		eq(right_client, result)
		assert(bufadd_called, "Expected slow path to be triggered (bufadd not called)")
		eq(42, set_ft_bufnr)
	end)

	-- Slice 3: slow path — preloads a java file and waits when no jdtls client is up yet.
	-- The wait loop detects the new client via root_dir matching, not bufnr.
	it("preloads a file, fires FileType, and waits when no client is available", function()
		local cwd = Path("/project/module-c")
		local client = make_client("/project/module-c")
		local bufadd_path = nil
		local bufload_path = nil
		local set_ft_bufnr = nil
		local filetype_set = false

		local provider = ClientProvider({
			get_clients = function()
				-- Once set_buf_filetype fires, simulate module-c's jdtls appearing
				if filetype_set then
					return { client }
				end
				return {}
			end,
			globpath = function()
				return { "/project/module-c/src/ATest.java" }
			end,
			bufadd = function(path)
				bufadd_path = path
				return 99
			end,
			bufload = function(path)
				bufload_path = path
			end,
			set_buf_filetype = function(bufnr)
				set_ft_bufnr = bufnr
				filetype_set = true
			end,
			hrtime = function()
				return 0
			end,
			sleep = function() end,
		})

		eq(client, provider(cwd))
		eq("/project/module-c/src/ATest.java", bufadd_path)
		eq("/project/module-c/src/ATest.java", bufload_path)
		eq(99, set_ft_bufnr)
	end)
end)
