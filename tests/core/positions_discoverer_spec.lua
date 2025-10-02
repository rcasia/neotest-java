---@module "luassert"
local _ = require("vim.treesitter") -- NOTE: needed for loading treesitter upfront for the tests
local async = require("nio").tests
local plugin = require("neotest-java")
local positions_discoverer = require("neotest-java.core.positions_discoverer_dev")

local eq = assert.are.same

describe("PositionsDiscoverer", function()
	local tmp_files

	before_each(function()
		tmp_files = {}
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

		eq({
			{
				id = "com.example",
				-- take the last node of the directory
				name = file_path:gsub(".*/", ""),
				path = file_path,
				range = { 0, 4, 8, 2 },
			},
			{
				{
					id = "com.example.Outer",
					name = "Outer",
					path = file_path,
					range = { 2, 4, 7, 5 },
					type = "namespace",
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
		local actual = assert(plugin.discover_positions(file_path))

		-- then
		local actual_list = actual:to_list()

		eq("simpleTestMethod", actual_list[2][2][1].name)

		eq(1, #actual:children()[1]:children())
	end)

	async.it("should discover ParameterizedTest", function()
		-- given
		local file_path = create_tmp_javafile([[
class Test {

  @ParameterizedTest
  @ValueSource(ints = {1, 2, 3})
  public void parameterizedTestWithValueSource(int i) {
    assertThat(i).isGreaterThan(0);
  }

  @ParameterizedTest
  @MethodSource("provideStringsForIsBlank")
  public void parameterizedTestWithMethodSource() {
    assertThat(1).isEqualTo(1);
  }

  @ParameterizedTest(name = "{0}")
  @MethodSource("provideStringsForIsBlank")
  public void parameterizedTestWithMethodSourceAndExplicitName() {
    assertThat(1).isEqualTo(1);
  }

}

		]])

		-- when
		local actual = assert(plugin.discover_positions(file_path))

		-- then
		local actual_list = actual:to_list()

		eq("parameterizedTestWithValueSource", actual_list[2][2][1].name)
		eq("parameterizedTestWithMethodSource", actual_list[2][3][1].name)
		eq("parameterizedTestWithMethodSourceAndExplicitName", actual_list[2][4][1].name)

		eq(3, #actual:children()[1]:children())
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
		local actual = assert(plugin.discover_positions(file_path))

		-- then
		local test_name = actual:to_list()[2][2][2][2][1].name
		eq(test_name, "someTest")

		local another_outer_test_name = actual:to_list()[2][2][3][1].name
		eq(another_outer_test_name, "oneMoreOuterTest")
	end)
end)
