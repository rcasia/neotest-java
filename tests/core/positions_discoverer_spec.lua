local async = require("nio").tests
local plugin = require("neotest-java")
local Tree = require("neotest.types").Tree

local current_dir = vim.fn.expand("%:p:h") .. "/"

describe("PositionsDiscoverer", function()
	async.it("should discover test method names", function()
		-- given
		local file_path = current_dir .. "tests/fixtures/Test.java"

		-- when
		local actual = plugin.discover_positions(file_path)

		-- then
		local actual_list = actual:to_list()

		assert.equals("shouldFindThis1", actual_list[2][2][1].name)
		assert.equals("shouldFindThis2", actual_list[2][3][1].name)
		assert.equals("shouldFindThis3", actual_list[2][4][1].name)
		assert.equals("shouldFindThis4", actual_list[2][5][1].name)

		-- should find 4 tests
		local actual_count = #actual:children()[1]:children()
		assert.equals(4, actual_count)
	end)

	async.it("should discover nested tests", function()
		-- given
		local file_path = current_dir .. "tests/fixtures/SomeNestedTest.java"

		-- when
		local actual = plugin.discover_positions(file_path)

		-- then
		local test_name = actual:to_list()[2][2][2][2][1].name
		assert.equals(test_name, "someTest")

		local another_outer_test_name = actual:to_list()[2][2][3][1].name
		assert.equals(another_outer_test_name, "oneMoreOuterTest")
	end)
end)
