local _ = require("vim.treesitter") -- NOTE: needed for loading treesitter upfront for the tests
local async = require("nio").tests
local plugin = require("neotest-java")

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

	async.it("should discover test method names", function()
		-- given
		local file_path = create_tmp_javafile([[
class Test {

  @Test
  public void shouldFindThis1() {
    assertThat(1).isEqualTo(1);
  }

  @ParameterizedTest
  @ValueSource(ints = {1, 2, 3})
  public void shouldFindThis2(int i) {
    assertThat(i).isGreaterThan(0);
  }

  @Test
  public void shouldFindThis3() {
    assertThat(1).isEqualTo(1);
  }

  @ParameterizedTest
  @MethodSource("provideStringsForIsBlank")
  public void shouldFindThis4() {
    assertThat(1).isEqualTo(1);
  }

  @ParameterizedTest(name = "{0}")
  @MethodSource("provideStringsForIsBlank")
  public void shouldFindThis5() {
    assertThat(1).isEqualTo(1);
  }

  private void assertThat(int i) {
    // do nothing
  }
}

		]])

		-- when
		local actual = plugin.discover_positions(file_path)

		-- then
		local actual_list = actual:to_list()

		assert.equals("shouldFindThis1", actual_list[2][2][1].name)
		assert.equals("shouldFindThis2", actual_list[2][3][1].name)
		assert.equals("shouldFindThis3", actual_list[2][4][1].name)
		assert.equals("shouldFindThis4", actual_list[2][5][1].name)
		assert.equals("shouldFindThis5", actual_list[2][6][1].name)

		-- should find 5 tests
		local actual_count = #actual:children()[1]:children()
		assert.equals(5, actual_count)
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
