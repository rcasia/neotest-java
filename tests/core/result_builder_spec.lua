local async = require("nio").tests
local plugin = require("neotest-java")

local current_dir = vim.fn.fnamemodify(vim.fn.expand("%:p:h"), ":p")

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
			cwd = current_dir .. "tests/fixtures/maven-demo",
			context = {
				project_type = "maven",
				test_class_names = { "com.example.ExampleTest" },
			},
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = table_to_string(results)
		local expected = [[
      {
        ["{{current_dir}}tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java::ExampleTest::shouldFail"] = {
          errors = {{ line=13, message="expected: <true> but was: <false>" }},
          short = "expected: <true> but was: <false>",
          status = "failed"
        },
        ["{{current_dir}}tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java::ExampleTest::shouldNotFail"] = {
          status = "passed"
        }
      }
    ]]

		expected = expected:gsub("{{current_dir}}", current_dir)

		assert_equal_ignoring_whitespaces(expected, actual)
	end)

	async.it("builds the results for a maven test that has an error at start", function()
		--given
		local runSpec = {
			cwd = current_dir .. "tests/fixtures/maven-demo",
			context = {
				project_type = "maven",
				test_class_names = { "com.example.ErroneousTest" },
			},
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ErroneousTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = table_to_string(results)
		local expected = [[
      {
        ["{{current_dir}}tests/fixtures/maven-demo/src/test/java/com/example/ErroneousTest.java::ErroneousTest::shouldFailOnError"] = {
	        errors = {{ message="Error creating bean with name 'com.example.ErroneousTest': Injection of autowired dependencies failed" }},
          short = "Error creating bean with name 'com.example.ErroneousTest': Injection of autowired dependencies failed",
          status = "failed"
        }
      }
    ]]

		expected = expected:gsub("{{current_dir}}", current_dir)

		assert_equal_ignoring_whitespaces(expected, actual)
	end)

	async.it("builds the results for gradle", function()
		--given
		local runSpec = {
			cwd = current_dir .. "tests/fixtures/gradle-groovy-demo",
			context = {
				project_type = "gradle",
				test_class_names = { "com.example.ExampleTest" },
			},
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = current_dir .. "tests/fixtures/gradle-groovy-demo/src/test/java/com/example/ExampleTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = table_to_string(results)
		local expected = [[
      {
        ["{{current_dir}}tests/fixtures/gradle-groovy-demo/src/test/java/com/example/ExampleTest.java::ExampleTest::shouldFail"] = {
	        errors = {{ line=14,message="org.opentest4j.AssertionFailedError:expected:<true>butwas:<false>" }},
          short = "org.opentest4j.AssertionFailedError:expected:<true>butwas:<false>",
          status = "failed"
        },
        ["{{current_dir}}tests/fixtures/gradle-groovy-demo/src/test/java/com/example/ExampleTest.java::ExampleTest::shouldNotFail"] = {
          status = "passed"
        }
      }
    ]]

		expected = expected:gsub("{{current_dir}}", current_dir)

		assert_equal_ignoring_whitespaces(expected, actual)
	end)

	async.it("builds the results when the is a single test method and it fails for gradle", function()
		--given
		local runSpec = {
			cwd = current_dir .. "tests/fixtures/gradle-groovy-demo",
			context = {
				project_type = "gradle",
				test_class_names = { "com.example.SingleMethodFailingTest" },
			},
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = current_dir
			.. "tests/fixtures/gradle-groovy-demo/src/test/java/com/example/SingleMethodFailingTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = table_to_string(results)
		local expected = [[
    {
      ["{{current_dir}}tests/fixtures/gradle-groovy-demo/src/test/java/com/example/SingleMethodFailingTest.java::SingleMethodFailingTest::shouldFail"] 
      = { 
	      errors = {{ line=9,message="org.opentest4j.AssertionFailedError:expected:<true>butwas:<false>" }},
        short = "org.opentest4j.AssertionFailedError:expected:<true>butwas:<false>",
        status = "failed"
      }
    }
    ]]
		expected = expected:gsub("{{current_dir}}", current_dir)

		assert_equal_ignoring_whitespaces(expected, actual)
	end)

	async.it("builds the results when the is a single test method and it fails for maven", function()
		--given
		local runSpec = {
			cwd = current_dir .. "tests/fixtures/maven-demo",
			context = {
				project_type = "maven",
				test_class_names = { "com.example.SingleMethodFailingTest" },
			},
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = current_dir
			.. "tests/fixtures/maven-demo/src/test/java/com/example/SingleMethodFailingTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = table_to_string(results)
		local expected = [[
    {
      ["{{current_dir}}tests/fixtures/maven-demo/src/test/java/com/example/SingleMethodFailingTest.java::SingleMethodFailingTest::shouldFail"] 
      = { 
        errors = {{ line=9, message="expected: <true> but was: <false>" }},
        short = "expected: <true> but was: <false>",
        status = "failed"
      }
    }
    ]]
		expected = expected:gsub("{{current_dir}}", current_dir)

		assert_equal_ignoring_whitespaces(expected, actual)
	end)

	async.it("builds the results for integrations tests", function()
		--given
		local runSpec = {
			cwd = current_dir .. "tests/fixtures/maven-demo",
			context = {
				project_type = "maven",
				test_class_names = { "com.example.demo.RepositoryIT" },
			},
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/demo/RepositoryIT.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = table_to_string(results)
		local expected = [[
      {
        ["{{current_dir}}tests/fixtures/maven-demo/src/test/java/com/example/demo/RepositoryIT.java::RepositoryIT::shouldWorkProperly"]

      = {status="passed"}
      }
    ]]

		expected = expected:gsub("{{current_dir}}", current_dir)

		assert_equal_ignoring_whitespaces(expected, actual)
	end)

	async.it("builds the results for parameterized test with @CsvSource for maven", function()
		--given
		local runSpec = {
			cwd = current_dir .. "tests/fixtures/maven-demo",
			context = {
				project_type = "maven",
				test_class_names = { "com.example.ParameterizedMethodTest" },
			},
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = current_dir
			.. "tests/fixtures/maven-demo/src/test/java/com/example/ParameterizedMethodTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = table_to_string(results)
		local expected = [[
	      {
		["{{current_dir}}tests/fixtures/maven-demo/src/test/java/com/example/ParameterizedMethodTest.java::ParameterizedMethodTest::parameterizedMethodShouldFail"]
		  = {
        errors={{message="
			  parameterizedMethodShouldFail(Integer, Integer)[1] -> org.opentest4j.AssertionFailedError: expected: <true> but was: <false>\n
			  parameterizedMethodShouldFail(Integer, Integer)[2] -> org.opentest4j.AssertionFailedError: expected: <true> but was: <false>
        "}},
		    short="
			  parameterizedMethodShouldFail(Integer, Integer)[1] -> org.opentest4j.AssertionFailedError: expected: <true> but was: <false>\n
			  parameterizedMethodShouldFail(Integer, Integer)[2] -> org.opentest4j.AssertionFailedError: expected: <true> but was: <false>
		    ",
		    status="failed"
		  }
	      ,
		["{{current_dir}}tests/fixtures/maven-demo/src/test/java/com/example/ParameterizedMethodTest.java::ParameterizedMethodTest::parameterizedMethodShouldNotFail"]
		  = {status="passed"}
	      }
	    ]]

		expected = expected:gsub("{{current_dir}}", current_dir)

		assert_equal_ignoring_whitespaces(expected, actual)
	end)

	async.it("builds the results for parameterized with @CsvSource test for gradle", function()
		--given
		local runSpec = {
			cwd = current_dir .. "tests/fixtures/gradle-groovy-demo",
			context = {
				project_type = "gradle",
				test_class_names = { "com.example.ParameterizedTests" },
				test_method_names = {
					"shouldFail",
					"shouldFail2",
					"shouldPass",
					"shouldPass2",
				},
			},
		}

		local strategyResult = {
			code = 0,
			output = "output",
		}

		local file_path = current_dir
			.. "tests/fixtures/gradle-groovy-demo/src/test/java/com/example/ParameterizedTests.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, strategyResult, tree)

		--then
		local actual = table_to_string(results)
		local expected = [[
      {
        ["{{current_dir}}tests/fixtures/gradle-groovy-demo/src/test/java/com/example/ParameterizedTests.java::ParameterizedTests::shouldFail"]
          = {
        errors= {{message="shouldFail(int,int,int)[1]->org.opentest4j.AssertionFailedError:expected:<true>butwas:<false>\nshouldFail(int,int,int)[2]->org.opentest4j.AssertionFailedError:expected:<true>butwas:<false>\nshouldFail(int,int,int)[3]->org.opentest4j.AssertionFailedError:expected:<true>butwas:<false>"}},
          short="shouldFail(int,int,int)[1]->org.opentest4j.AssertionFailedError:expected:<true>butwas:<false>\nshouldFail(int,int,int)[2]->org.opentest4j.AssertionFailedError:expected:<true>butwas:<false>\nshouldFail(int,int,int)[3]->org.opentest4j.AssertionFailedError:expected:<true>butwas:<false>",
          status="failed"
          }
        ,
        ["{{current_dir}}tests/fixtures/gradle-groovy-demo/src/test/java/com/example/ParameterizedTests.java::ParameterizedTests::shouldFail2"]
          = {
        errors= {{message="shouldFail2(int,int,int)[2]->org.opentest4j.AssertionFailedError:expected:<true>butwas:<false>\nshouldFail2(int,int,int)[3]->org.opentest4j.AssertionFailedError:expected:<true>butwas:<false>"}},
          short="shouldFail2(int,int,int)[2]->org.opentest4j.AssertionFailedError:expected:<true>butwas:<false>\nshouldFail2(int,int,int)[3]->org.opentest4j.AssertionFailedError:expected:<true>butwas:<false>",
          status="failed"
          }
        ,
        ["{{current_dir}}tests/fixtures/gradle-groovy-demo/src/test/java/com/example/ParameterizedTests.java::ParameterizedTests::shouldPass"]
          = {status="passed"}
        ,
        ["{{current_dir}}tests/fixtures/gradle-groovy-demo/src/test/java/com/example/ParameterizedTests.java::ParameterizedTests::shouldPass2"]
          = {status="passed"}
      }
    ]]

		expected = expected:gsub("{{current_dir}}", current_dir)

		assert_equal_ignoring_whitespaces(expected, actual)
	end)

	for _, project_type in ipairs({ "maven", "gradle" }) do
		async.it("builds the results for parameterized with @EmptySource test for " .. project_type, function()
			--given
			local project_dir = project_type == "maven" and "maven-demo" or "gradle-groovy-demo"
			local runSpec = {
				cwd = current_dir .. "tests/fixtures/" .. project_dir,
				context = {
					project_type = project_type,
					test_class_names = { "com.example.EmptySourceTest" },
					test_method_names = {
						"emptySourceShouldFail",
						"emptySourceShouldPass",
					},
				},
			}

			local strategyResult = {
				code = 0,
				output = "output",
			}

			local file_path = current_dir
				.. "tests/fixtures/"
				.. project_dir
				.. "/src/test/java/com/example/EmptySourceTest.java"
			local tree = plugin.discover_positions(file_path)

			--when
			local results = plugin.results(runSpec, strategyResult, tree)

			--then
			local actual = table_to_string(results)

			local expected = [[
      {
        ["{{current_dir}}tests/fixtures/{{project_dir}}/src/test/java/com/example/EmptySourceTest.java::EmptySourceTest::emptySourceShouldFail"]
          = {
          errors={{message="emptySourceShouldFail(String)[1] -> org.opentest4j.AssertionFailedError: expected: <false> but was: <true>"}},
          short="emptySourceShouldFail(String)[1] -> org.opentest4j.AssertionFailedError: expected: <false> but was: <true>",
          status="failed"
          }
        ,
        ["{{current_dir}}tests/fixtures/{{project_dir}}/src/test/java/com/example/EmptySourceTest.java::EmptySourceTest::emptySourceShouldPass"]
          = {status="passed"}
      }
    ]]

			expected = expected:gsub("{{current_dir}}", current_dir)
			expected = expected:gsub("{{project_dir}}", project_dir)

			assert_equal_ignoring_whitespaces(expected, actual)
		end)
	end
end)
