---@module "luassert"
local _ = require("vim.treesitter") -- NOTE: needed for loading treesitter upfront for the tests
local neotest_lib = require("neotest.lib")

local assertions = require("tests.assertions")

local eq = assertions.eq
local PositionsDiscoverer = require("neotest-java.core.positions_discoverer")

-- Helper function to remove 'ref' field from tree structure for comparison
local function remove_ref_field(tbl)
	if type(tbl) ~= "table" then
		return tbl
	end
	local result = {}
	for k, v in pairs(tbl) do
		if k ~= "ref" then
			if type(v) == "table" then
				result[k] = remove_ref_field(v)
			else
				result[k] = v
			end
		end
	end
	return result
end

-- Synchronous file reader injected in place of neotest.lib.file.read (which is async).
-- Uses Lua's io.open so no coroutine yields are needed.
local function sync_read_file(path)
	local filepath = path:to_string()
	local f = assert(io.open(filepath, "r"), "sync_read_file: cannot open " .. filepath)
	local content = f:read("*a")
	f:close()
	return content
end

-- Synchronous parse_positions injected in place of neotest.lib.treesitter.parse_positions.
-- Reads the file with io.open (no async) then delegates to parse_positions_from_string.
-- opts already contains build_position and position_id as closures (injected by
-- PositionsDiscoverer), so no subprocess serialisation is needed.
local function sync_parse_positions(file_path, query, opts)
	local f = assert(io.open(file_path, "r"), "sync_parse_positions: cannot open " .. file_path)
	local content = f:read("*a")
	f:close()
	return neotest_lib.treesitter.parse_positions_from_string(file_path, content, query, opts)
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
			-- Inject synchronous implementations so the tests need no async context.
			parse_positions = sync_parse_positions,
			read_file = sync_read_file,
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

	it("method FQN with inner classes", function()
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
							id = "com.example.Outer$Inner#simpleTestMethod()",
							name = "simpleTestMethod",
							path = file_path,
							range = { 4, 8, 5, 34 },
							type = "test",
						},
					},
				},
			},
		}, remove_ref_field(result:to_list()))
	end)

	it("should discover simple test method", function()
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

		-- then
		local actual_list = actual:to_list()

		eq("simpleTestMethod", actual_list[2][2][1].name)

		eq(1, #actual:children()[1]:children())
	end)

	it("should discover two simple test method", function()
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
						id = "Test#firstTestMethod()",
						name = "firstTestMethod",
						path = file_path,
						range = { 2, 2, 5, 3 },
						type = "test",
					},
				},
				{
					{
						id = "Test#secondTestMethod()",
						name = "secondTestMethod",
						path = file_path,
						range = { 7, 2, 10, 3 },
						type = "test",
					},
				},
			},
		}, remove_ref_field(actual_list))
	end)

	it("should discover nested tests", function()
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
								id = "SomeTest$SomeNestedTest$AnotherNestedTest#someTest()",
								name = "someTest",
								path = file_path,
								range = { 3, 12, 6, 13 },
								type = "test",
							},
						},
					},
					{
						{
							id = "SomeTest$SomeNestedTest#oneMoreOuterTest()",
							name = "oneMoreOuterTest",
							path = file_path,
							range = { 9, 8, 12, 9 },
							type = "test",
						},
					},
				},
			},
		}, remove_ref_field(actual:to_list()))
	end)
end)
