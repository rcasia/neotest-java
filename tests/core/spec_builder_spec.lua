local async = require("plenary.async").tests
local plugin = require("neotest-java")
local Tree = require("neotest.types.tree")

local function getCurrentDir()
	return vim.fn.fnamemodify(vim.fn.expand("%:p:h"), ":p")
end

describe("SpecBuilder", function()
	async.it("builds the spec for method", function()
		local path = getCurrentDir() .. "tests/fixtures/demo/src/test/java/com/example/ExampleTest.java"

		local args = {
			tree = {
				data = function()
					return {
						path = path,
						name = "shouldNotFail",
					}
				end,
			},
			extra_args = {},
		}

		-- when
		local actual = plugin.build_spec(args)

		-- then
		local expected_position = "com.example.ExampleTest#shouldNotFail"

		local expected_command = "mvn clean test -Dtest=" .. expected_position
		local expected_cwd = getCurrentDir() .. "tests/fixtures/demo"

		assert.are.equal(expected_command, actual.command)
		assert.are.equal(expected_cwd, actual.cwd)
	end)

	async.it("builds the spec for class", function()
		local args = {
			tree = {
				data = function()
					return {
						path = getCurrentDir() .. "tests/fixtures/demo/src/test/java/com/example/ExampleTest.java",
						name = "ExampleTest",
					}
				end,
			},
			extra_args = {},
		}

		-- when
		local actual = plugin.build_spec(args)

		-- then
		local expected_position = "com.example.ExampleTest#ExampleTest"

		local expected_command = "mvn clean test -Dtest=" .. expected_position
		local expected_cwd = getCurrentDir() .. "tests/fixtures/demo"

		assert.are.equal(expected_command, actual.command)
		assert.are.equal(expected_cwd, actual.cwd)
	end)
end)
