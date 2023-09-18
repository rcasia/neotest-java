local async = require("nio").tests
local plugin = require("neotest-java")

local function getCurrentDir()
	return vim.fn.fnamemodify(vim.fn.expand("%:p:h"), ":p")
end

-- Function to convert a Lua table to a string
function tableToString(tbl)
	return vim.inspect(tbl)
end

function assert_equal_ignoring_whitespaces(expected, actual)
	assert.are.equal(expected:gsub("%s+", ""), actual:gsub("%s+", ""))
end

describe("ResultBuilder", function()
	async.it("builds the results", function()
		--given
		local runSpec = {
			cwd = getCurrentDir() .. "tests/fixtures/maven-demo",
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = getCurrentDir() .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = tableToString(results)
		local expected = [[
      {
        ["{{currentDir}}tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java::shouldFail"] = {
          status = "failed"
        },
        ["{{currentDir}}tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java::shouldNotFail"] = {
          status = "passed"
        }
      }
    ]]

		expected = expected:gsub("{{currentDir}}", getCurrentDir())

		assert_equal_ignoring_whitespaces(expected, actual)
	end)

	async.it("builds the results when the is a single test method and it fails", function()
		--given
		local runSpec = {
			cwd = getCurrentDir() .. "tests/fixtures/maven-demo",
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = getCurrentDir()
			.. "tests/fixtures/maven-demo/src/test/java/com/example/SingleMethodFailingTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = tableToString(results)
		local expected = [[
    {
      ["{{currentDir}}tests/fixtures/maven-demo/src/test/java/com/example/SingleMethodFailingTest.java::shouldFail"] 

      = { status = "failed" }
    }
    ]]
		expected = expected:gsub("{{currentDir}}", getCurrentDir())

		assert_equal_ignoring_whitespaces(expected, actual)
	end)

	async.it("builds the results for integrations tests", function()
		--given
		local runSpec = {
			cwd = getCurrentDir() .. "tests/fixtures/maven-demo",
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = getCurrentDir()
			.. "tests/fixtures/maven-demo/src/test/java/com/example/demo/RepositoryIT.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = tableToString(results)
		local expected = [[
      {
        ["{{currentDir}}tests/fixtures/maven-demo/src/test/java/com/example/demo/RepositoryIT.java::shouldWorkProperly"]

      = {status="passed"}
      }
    ]]

		expected = expected:gsub("{{currentDir}}", getCurrentDir())

		assert_equal_ignoring_whitespaces(expected, actual)
	end)

	async.it("builds the results for parameterized test", function()
		--given
		local runSpec = {
			cwd = getCurrentDir() .. "tests/fixtures/maven-demo",
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = getCurrentDir()
			.. "tests/fixtures/maven-demo/src/test/java/com/example/ParameterizedMethodTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = tableToString(results)
		local expected = [[
      {
        ["{{currentDir}}tests/fixtures/maven-demo/src/test/java/com/example/ParameterizedMethodTest.java::parameterizedMethodShouldFail"]
          = {status="failed"}
      ,
        ["{{currentDir}}tests/fixtures/maven-demo/src/test/java/com/example/ParameterizedMethodTest.java::parameterizedMethodShouldNotFail"]
          = {status="passed"}
      }
    ]]

		expected = expected:gsub("{{currentDir}}", getCurrentDir())

		assert_equal_ignoring_whitespaces(expected, actual)
	end)
end)
