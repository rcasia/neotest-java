local async = require("nio").tests
local plugin = require("neotest-java")

local function get_current_dir()
	return vim.fn.fnamemodify(vim.fn.expand("%:p:h"), ":p")
end

-- Function to convert a Lua table to a string
function table_to_string(tbl)
	return vim.inspect(tbl)
end

function assert_equal_ignoring_whitespaces(expected, actual)
	assert.are.equal(expected:gsub("%s+", ""), actual:gsub("%s+", ""))
end

describe("ResultBuilder", function()
	async.it("builds the results for maven", function()
		--given
		local runSpec = {
			cwd = get_current_dir() .. "tests/fixtures/maven-demo",
			context = {
				project_type = "maven",
				test_class_path = "com.example.ExampleTest",
			},
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = get_current_dir() .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = table_to_string(results)
		local expected = [[
      {
        ["{{current_dir}}tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java::shouldFail"] = {
          short = "expected: <true> but was: <false>",
          status = "failed"
        },
        ["{{current_dir}}tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java::shouldNotFail"] = {
          status = "passed"
        }
      }
    ]]

		expected = expected:gsub("{{current_dir}}", get_current_dir())

		assert_equal_ignoring_whitespaces(expected, actual)
	end)

	async.it("builds the results for gradle", function()
		--given
		local runSpec = {
			cwd = get_current_dir() .. "tests/fixtures/gradle-demo",
			context = {
				project_type = "gradle",
				test_class_path = "com.example.ExampleTest",
			},
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = get_current_dir() .. "tests/fixtures/gradle-demo/src/test/java/com/example/ExampleTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = table_to_string(results)
		local expected = [[
      {
        ["{{current_dir}}tests/fixtures/gradle-demo/src/test/java/com/example/ExampleTest.java::shouldFail"] = {
          short = "org.opentest4j.AssertionFailedError:expected:<true>butwas:<false>",
          status = "failed"
        },
        ["{{current_dir}}tests/fixtures/gradle-demo/src/test/java/com/example/ExampleTest.java::shouldNotFail"] = {
          status = "passed"
        }
      }
    ]]

		expected = expected:gsub("{{current_dir}}", get_current_dir())

		assert_equal_ignoring_whitespaces(expected, actual)
	end)

	async.it("builds the results when the is a single test method and it fails for gradle", function()
		--given
		local runSpec = {
			cwd = get_current_dir() .. "tests/fixtures/gradle-demo",
			context = {
				project_type = "gradle",
				test_class_path = "com.example.SingleMethodFailingTest",
			},
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = get_current_dir()
			.. "tests/fixtures/gradle-demo/src/test/java/com/example/SingleMethodFailingTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = table_to_string(results)
		local expected = [[
    {
      ["{{current_dir}}tests/fixtures/gradle-demo/src/test/java/com/example/SingleMethodFailingTest.java::shouldFail"] 
      = { 
        short = "org.opentest4j.AssertionFailedError:expected:<true>butwas:<false>",
        status = "failed"
      }
    }
    ]]
		expected = expected:gsub("{{current_dir}}", get_current_dir())

		assert_equal_ignoring_whitespaces(expected, actual)
	end)

	async.it("builds the results when the is a single test method and it fails for maven", function()
		--given
		local runSpec = {
			cwd = get_current_dir() .. "tests/fixtures/maven-demo",
			context = {
				project_type = "maven",
				test_class_path = "com.example.SingleMethodFailingTest",
			},
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = get_current_dir()
			.. "tests/fixtures/maven-demo/src/test/java/com/example/SingleMethodFailingTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = table_to_string(results)
		local expected = [[
    {
      ["{{current_dir}}tests/fixtures/maven-demo/src/test/java/com/example/SingleMethodFailingTest.java::shouldFail"] 
      = { 
        short = "expected: <true> but was: <false>",
        status = "failed"
      }
    }
    ]]
		expected = expected:gsub("{{current_dir}}", get_current_dir())

		assert_equal_ignoring_whitespaces(expected, actual)
	end)

	async.it("builds the results for integrations tests", function()
		--given
		local runSpec = {
			cwd = get_current_dir() .. "tests/fixtures/maven-demo",
			context = {
				project_type = "maven",
				test_class_path = "com.example.demo.RepositoryIT",
			},
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = get_current_dir()
			.. "tests/fixtures/maven-demo/src/test/java/com/example/demo/RepositoryIT.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = table_to_string(results)
		local expected = [[
      {
        ["{{current_dir}}tests/fixtures/maven-demo/src/test/java/com/example/demo/RepositoryIT.java::shouldWorkProperly"]

      = {status="passed"}
      }
    ]]

		expected = expected:gsub("{{current_dir}}", get_current_dir())

		assert_equal_ignoring_whitespaces(expected, actual)
	end)

	async.it("builds the results for parameterized test for maven", function()
		--given
		local runSpec = {
			cwd = get_current_dir() .. "tests/fixtures/maven-demo",
			context = {
				project_type = "maven",
				test_class_path = "com.example.ParameterizedMethodTest",
			},
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = get_current_dir()
			.. "tests/fixtures/maven-demo/src/test/java/com/example/ParameterizedMethodTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = table_to_string(results)
		local expected = [[
	      {
		["{{current_dir}}tests/fixtures/maven-demo/src/test/java/com/example/ParameterizedMethodTest.java::parameterizedMethodShouldFail"]
		  = {
		    short="
			  parameterizedMethodShouldFail(Integer, Integer)[1] -> org.opentest4j.AssertionFailedError: expected: <true> but was: <false>\n
			  parameterizedMethodShouldFail(Integer, Integer)[2] -> org.opentest4j.AssertionFailedError: expected: <true> but was: <false>
		    ",
		    status="failed"
		  }
	      ,
		["{{current_dir}}tests/fixtures/maven-demo/src/test/java/com/example/ParameterizedMethodTest.java::parameterizedMethodShouldNotFail"]
		  = {status="passed"}
	      }
	    ]]

		expected = expected:gsub("{{current_dir}}", get_current_dir())

		assert_equal_ignoring_whitespaces(expected, actual)
	end)

	async.it("builds the results for parameterized test for gradle", function()
		--given
		local runSpec = {
			cwd = get_current_dir() .. "tests/fixtures/gradle-demo",
			context = {
				project_type = "gradle",
				test_class_path = "com.example.ParameterizedMethodTest",
				test_method_names = {
					"shouldFail",
					"shouldPass",
					"shouldPass2",
				},
			},
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = get_current_dir()
			.. "tests/fixtures/gradle-demo/src/test/java/com/example/ParameterizedTests.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = table_to_string(results)
		local expected = [[
      {
        ["{{current_dir}}tests/fixtures/gradle-demo/src/test/java/com/example/ParameterizedTests.java::shouldFail"]
          = {
          short="org.opentest4j.AssertionFailedError:expected:<true>butwas:<false>",
          status="failed"
          }
        ,
        ["{{current_dir}}tests/fixtures/gradle-demo/src/test/java/com/example/ParameterizedTests.java::shouldPass"]
          = {status="passed"}
        ,
        ["{{current_dir}}tests/fixtures/gradle-demo/src/test/java/com/example/ParameterizedTests.java::shouldPass2"]
          = {status="passed"}
      }
    ]]

		expected = expected:gsub("{{current_dir}}", get_current_dir())

		assert_equal_ignoring_whitespaces(expected, actual)
	end)
end)
