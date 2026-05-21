---@module "luassert"
local _ = require("vim.treesitter") -- NOTE: needed for loading treesitter upfront for the tests

local assertions = require("tests.assertions")
local async = require("tests.async_helpers").async

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

	---@param content string
	---@return string filename
	local function create_tmp_groovyfile(content)
		local tmp_file = os.tmpname() .. ".groovy"
		table.insert(tmp_files, tmp_file)
		local file = assert(io.open(tmp_file, "w"))
		file:write(content)
		file:close()
		return tmp_file
	end

	it(
		"method FQN with inner classes",
		async(function()
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
	)

	it(
		"should discover simple test method",
		async(function()
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
	)

	it(
		"should discover two simple test method",
		async(function()
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
	)

	it(
		"should discover nested tests",
		async(function()
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
	)

	it(
		"should discover Spock feature methods with string literal names",
		async(function()
			-- Skip if Groovy parser is not available
			local parser_dir = "./.dependencies/nvim-treesitter/parser"
			local groovy_so = parser_dir .. "/groovy.so"
			if vim.fn.filereadable(groovy_so) ~= 1 then
				print("Skipping: Groovy treesitter parser not available")
				return
			end

			local file_path = create_tmp_groovyfile([[
package com.example

import spock.lang.Specification

class CalculatorSpec extends Specification {

    def "addition of two positive numbers"() {
        expect:
        2 + 3 == 5
    }

    def "subtraction returns correct result"() {
        expect:
        10 - 4 == 6
    }
}
]])

			local result = assert(positions_discoverer.discover_positions(file_path))
			local actual_list = result:to_list()

			-- Should have file -> namespace (CalculatorSpec) -> tests
			local namespace = actual_list[2][1]
			eq("namespace", namespace.type)
			eq("CalculatorSpec", namespace.name)

			-- Should have 2 test methods
			local test_count = 0
			for _, child in ipairs(actual_list[2]) do
				if #child > 0 then
					for _, test in ipairs(child) do
						if test.type == "test" then
							test_count = test_count + 1
						end
					end
				end
			end
			eq(2, test_count, "Should discover 2 Spock feature methods")
		end)
	)

	it(
		"should discover JUnit-style annotated methods in Groovy",
		async(function()
			-- Skip if Groovy parser is not available
			local parser_dir = "./.dependencies/nvim-treesitter/parser"
			local groovy_so = parser_dir .. "/groovy.so"
			if vim.fn.filereadable(groovy_so) ~= 1 then
				print("Skipping: Groovy treesitter parser not available")
				return
			end

			local file_path = create_tmp_groovyfile([[
package com.example

import org.junit.jupiter.api.Test
import static org.junit.jupiter.api.Assertions.*

class UserServiceTest {

    @Test
    void "should create user with valid name"() {
        assertNotNull(user)
    }

    @Test
    void shouldReturnUserCount() {
        assertEquals(2, userCount)
    }
}
]])

			local result = assert(positions_discoverer.discover_positions(file_path))
			local actual_list = result:to_list()

			-- Should have 2 test methods
			local test_count = 0
			for _, child in ipairs(actual_list[2]) do
				if #child > 0 then
					for _, test in ipairs(child) do
						if test.type == "test" then
							test_count = test_count + 1
						end
					end
				end
			end
			eq(2, test_count, "Should discover 2 JUnit-style Groovy tests")
		end)
	)
end)
