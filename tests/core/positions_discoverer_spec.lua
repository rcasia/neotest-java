local async = require("plenary.async.tests")
local plugin = require("neotest-java")
local Tree = require("neotest.types").Tree

describe("PositionsDiscoverer", function()
	async.it("should discover test method names", function()
		-- given
		local file_path = "./tests/fixtures/Test.java"

		-- when
		local actual = plugin.discover_positions(file_path)

		-- then
		local actual_list = actual:to_list()

		-- for debugging
		print(actual)
		print("value: " .. actual_list[3][1].name)

		assert.equals(actual_list[2][1].name, "shouldFindThis1")
		assert.equals(actual_list[3][1].name, "shouldFindThis2")
		assert.equals(actual_list[4][1].name, "shouldFindThis3")
		assert.equals(actual_list[5][1].name, "shouldFindThis4")
	end)
end)
