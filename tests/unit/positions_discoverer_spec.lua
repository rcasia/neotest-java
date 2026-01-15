---@module "luassert"
local _ = require("vim.treesitter") -- NOTE: needed for loading treesitter upfront for the tests
local async = require("nio").tests
local nio = require("nio")

local assertions = require("tests.assertions")

local eq = assertions.eq
local PositionsDiscoverer = require("neotest-java.core.positions_discoverer")

--- A non-blocking replacement for vim.wait inside nio tasks
-- @param timeout_ms number: Max time to wait
-- @param condition function: Returns true when ready
-- @param interval_ms number: (Optional) Check frequency, default 10ms
local function nio_wait(timeout_ms, condition, interval_ms)
	interval_ms = interval_ms or 10
	local elapsed = 0

	while not condition() do
		if elapsed >= timeout_ms then
			return false, -1 -- Timed out
		end
		nio.sleep(interval_ms) -- Yields execution to allow other events to process
		elapsed = elapsed + interval_ms
	end

	return true -- Success
end

describe("PositionsDiscoverer", function()
	local tmp_files
	--- @type neotest-java.PositionsDiscoverer
	local positions_discoverer

	before_each(function()
		tmp_files = {}
		positions_discoverer = PositionsDiscoverer({
			method_id_resolver = {
				resolve_complete_method_id = function(_, method_id)
					return method_id
				end,
			},
		})
	end)

	after_each(function()
		-- clear temporary files
		for _, file in ipairs(tmp_files) do
			os.remove(file)
		end
	end)

	---@param content string
	---@return string filename
	local function create_tmp_javafile(content)
		local tmp_file = os.tmpname() .. ".java"
		table.insert(tmp_files, tmp_file)
		local file = assert(io.open(tmp_file, "w"))
		file:write(content)
		file:close()
		return tmp_file
	end

	async.it("method FQN with inner classes", function()
		local file_path = create_tmp_javafile([[
    package com.example;

    class Outer {
      class Inner {
        @Test
        void simpleTestMethod() {}
      }
    }
  ]])

		--- @type neotest.Tree
		local result = assert(positions_discoverer.discover_positions(file_path))

		nio_wait(10, function()
			return false
		end)

		eq({
			{
				id = file_path,
				name = file_path:gsub(".*/", ""):gsub(".*\\", ""),
				path = file_path,
				range = { 0, 4, 8, 2 },
				type = "file",
			},
			{
				{
					id = "com.example.Outer",
					name = "Outer",
					path = file_path,
					range = { 2, 4, 7, 5 },
					type = "namespace",
				},
				{
					{
						id = "com.example.Outer$Inner",
						name = "Inner",
						path = file_path,
						range = { 3, 6, 6, 7 },
						type = "namespace",
					},
					{
						{
							id = "com.example.Outer$Inner#simpleTestMethod",
							name = "simpleTestMethod",
							path = file_path,
							range = { 4, 8, 5, 34 },
							type = "test",
						},
					},
				},
			},
		}, result:to_list())
	end)

	async.it("should discover simple test method", function()
		-- given
		local file_path = create_tmp_javafile([[
class Test {

  @Test
  public void simpleTestMethod() {
    assertThat(1).isEqualTo(1);
  }

	public void notATestMethod() {
		assertThat(1).isEqualTo(1);
	}

}
		]])

		-- when
		--- @type neotest.Tree
		local actual = assert(positions_discoverer.discover_positions(file_path))

		nio_wait(10, function()
			return false
		end)

		-- then
		local actual_list = actual:to_list()

		eq("simpleTestMethod", actual_list[2][2][1].name)

		eq(1, #actual:children()[1]:children())
	end)

	async.it("should discover two simple test method", function()
		-- given
		local file_path = create_tmp_javafile([[
class Test {

  @Test
  public void firstTestMethod() {
    assertThat(1).isEqualTo(1);
  }

  @Test
  public void secondTestMethod() {
    assertThat(1).isEqualTo(1);
  }

}
		]])

		-- when
		--- @type neotest.Tree
		local actual = assert(positions_discoverer.discover_positions(file_path))

		nio_wait(10, function()
			return false
		end)

		-- then
		local actual_list = actual:to_list()

		eq({
			{
				id = file_path,
				name = file_path:gsub(".*/", ""):gsub(".*\\", ""),
				path = file_path,
				range = { 0, 0, 13, 2 },
				type = "file",
			},
			{
				{
					id = "Test",
					name = "Test",
					path = file_path,
					range = { 0, 0, 12, 1 },
					type = "namespace",
				},
				{
					{
						id = "Test#firstTestMethod",
						name = "firstTestMethod",
						path = file_path,
						range = { 2, 2, 5, 3 },
						type = "test",
					},
				},
				{
					{
						id = "Test#secondTestMethod",
						name = "secondTestMethod",
						path = file_path,
						range = { 7, 2, 10, 3 },
						type = "test",
					},
				},
			},
		}, actual_list)
	end)

	async.it("should discover nested tests", function()
		local file_path = create_tmp_javafile([[
public class SomeTest {
    public static class SomeNestedTest {
        public static class AnotherNestedTest {
            @Test
            public void someTest() {
                assertEquals(1 + 1, 2);
            }
        }

        @Test
        public void oneMoreOuterTest() {
            assertEquals(1 + 1, 2);
        }
    }
}
		]])

		-- when
		--- @type neotest.Tree
		local actual = assert(positions_discoverer.discover_positions(file_path))

		nio_wait(10, function()
			return false
		end)

		eq({
			{
				id = file_path,
				name = file_path:gsub(".*/", ""):gsub(".*\\", ""),
				path = file_path,
				range = { 0, 0, 15, 2 },
				type = "file",
			},
			{
				{
					id = "SomeTest",
					name = "SomeTest",
					path = file_path,
					range = { 0, 0, 14, 1 },
					type = "namespace",
				},
				{
					{
						id = "SomeTest$SomeNestedTest",
						name = "SomeNestedTest",
						path = file_path,
						range = { 1, 4, 13, 5 },
						type = "namespace",
					},
					{
						{
							id = "SomeTest$SomeNestedTest$AnotherNestedTest",
							name = "AnotherNestedTest",
							path = file_path,
							range = { 2, 8, 7, 9 },
							type = "namespace",
						},
						{
							{
								id = "SomeTest$SomeNestedTest$AnotherNestedTest#someTest",
								name = "someTest",
								path = file_path,
								range = { 3, 12, 6, 13 },
								type = "test",
							},
						},
					},
					{
						{
							id = "SomeTest$SomeNestedTest#oneMoreOuterTest",
							name = "oneMoreOuterTest",
							path = file_path,
							range = { 9, 8, 12, 9 },
							type = "test",
						},
					},
				},
			},
		}, actual:to_list())
	end)
end)
