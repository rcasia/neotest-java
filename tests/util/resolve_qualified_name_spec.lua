---@diagnostic disable: undefined-field
local async = require("nio").tests
local resolve_qualified_name = require("neotest-java.util.resolve_qualified_name")

local cwd = vim.fn.getcwd()
local EXAMPLE_FILEPATH = cwd .. "/tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java"
local EXAMPLE_PACKAGE = "com.example.ExampleTest"
local BAD_EXAMPLE_FILEPATH = cwd .. "/tests/fixtures/maven-demo/src/test/java/com/example/NonExistentTest.java"

describe("resolve_qualified_name function", function()
	async.it("it should resolve package from filename", function()
		assert.are.equal(EXAMPLE_PACKAGE, resolve_qualified_name(EXAMPLE_FILEPATH))
	end)

	async.it("it should error when file does not exist", function()
		assert.has_error(function()
			resolve_qualified_name(BAD_EXAMPLE_FILEPATH)
		end, string.format("file does not exist: %s", BAD_EXAMPLE_FILEPATH))
	end)
end)
