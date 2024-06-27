local async = require("nio").tests
local plugin = require("neotest-java")
local tempname_fn = require("nio").fn.tempname

local current_dir = vim.fn.fnamemodify(vim.fn.expand("%:p:h"), ":p")
local TEMPNAME = "/tmp/tempname-1234"

describe("ResultBuilder", function()
	async.before_each(function()
		-- mock the tempname function to return a fixed value
		require("nio").fn.tempname = function()
			return TEMPNAME
		end
	end)

	async.after_each(function()
		require("nio").fn.tempname = tempname_fn
	end)

	async.it("builds the results for maven", function()
		--given
		local runSpec = {
			cwd = vim.loop.cwd() .. "/tests/fixtures/maven-demo",
			context = {
				report_file = vim.loop.cwd()
					.. "/tests/fixtures/maven-demo/target/surefire-reports/TEST-com.example.ExampleTest.xml",
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
		local expected = {
			[current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java::ExampleTest::shouldFail"] = {
				errors = { { line = 13, message = "expected: <true> but was: <false>" } },
				short = "expected: <true> but was: <false>",
				status = "failed",
				output = TEMPNAME,
			},
			[current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java::ExampleTest::shouldNotFail"] = {
				status = "passed",
				output = TEMPNAME,
			},
		}

		assert.are.same(expected, results)
	end)

	async.it("builds the results for a maven test that has an error at start", function()
		--given
		local runSpec = {
			cwd = current_dir .. "tests/fixtures/maven-demo",
			context = {
				report_file = vim.loop.cwd()
					.. "/tests/fixtures/maven-demo/target/surefire-reports/TEST-com.example.ErroneousTest.xml",
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
		local expected = {
			[current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ErroneousTest.java::ErroneousTest::shouldFailOnError"] = {
				errors = {
					{
						message = "Error creating bean with name 'com.example.ErroneousTest': Injection of autowired dependencies failed",
					},
				},
				output = TEMPNAME,
				short = "Error creating bean with name 'com.example.ErroneousTest': Injection of autowired dependencies failed",
				status = "failed",
			},
		}

		assert.are.same(expected, results)
	end)

	async.it("builds the results for gradle", function()
		--given
		local runSpec = {
			cwd = current_dir .. "tests/fixtures/gradle-groovy-demo",
			context = {
				report_file = vim.loop.cwd()
					.. "/tests/fixtures/gradle-groovy-demo/build/test-results/test/TEST-com.example.ExampleTest.xml",
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
		local expected = {
			[current_dir .. "tests/fixtures/gradle-groovy-demo/src/test/java/com/example/ExampleTest.java::ExampleTest::shouldFail"] = {
				errors = {
					{ line = 14, message = "org.opentest4j.AssertionFailedError: expected: <true> but was: <false>" },
				},
				output = TEMPNAME,
				short = "org.opentest4j.AssertionFailedError: expected: <true> but was: <false>",
				status = "failed",
			},
			[current_dir .. "tests/fixtures/gradle-groovy-demo/src/test/java/com/example/ExampleTest.java::ExampleTest::shouldNotFail"] = {
				status = "passed",
				output = TEMPNAME,
			},
		}
		assert.are.same(expected, results)
	end)

	async.it("builds the results when the is a single test method and it fails for gradle", function()
		--given
		local runSpec = {
			cwd = current_dir .. "tests/fixtures/gradle-groovy-demo",
			context = {
				report_file = vim.loop.cwd()
					.. "/tests/fixtures/gradle-groovy-demo/build/test-results/test/TEST-com.example.SingleMethodFailingTest.xml",
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
		local expected = {
			[current_dir .. "tests/fixtures/gradle-groovy-demo/src/test/java/com/example/SingleMethodFailingTest.java::SingleMethodFailingTest::shouldFail"] = {
				errors = {
					{ line = 9, message = "org.opentest4j.AssertionFailedError: expected: <true> but was: <false>" },
				},
				short = "org.opentest4j.AssertionFailedError: expected: <true> but was: <false>",
				status = "failed",
				output = TEMPNAME,
			},
		}

		assert.are.same(expected, results)
	end)

	async.it("builds the results when the is a single test method and it fails for maven", function()
		--given
		local runSpec = {
			cwd = current_dir .. "tests/fixtures/maven-demo",
			context = {
				report_file = vim.loop.cwd()
					.. "/tests/fixtures/gradle-groovy-demo/build/test-results/test/TEST-com.example.SingleMethodFailingTest.xml",
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
		local expected = {
			[current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/SingleMethodFailingTest.java::SingleMethodFailingTest::shouldFail"] = {
				errors = {
					{ line = 9, message = "org.opentest4j.AssertionFailedError: expected: <true> but was: <false>" },
				},
				short = "org.opentest4j.AssertionFailedError: expected: <true> but was: <false>",
				status = "failed",
				output = TEMPNAME,
			},
		}

		assert.are.same(expected, results)
	end)

	async.it("builds the results for integrations tests", function()
		--given
		local runSpec = {
			cwd = current_dir .. "tests/fixtures/maven-demo",
			context = {
				report_file = vim.loop.cwd()
					.. "/tests/fixtures/maven-demo/target/surefire-reports/TEST-com.example.demo.RepositoryIT.xml",
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
		local expected = {
			[current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/demo/RepositoryIT.java::RepositoryIT::shouldWorkProperly"] = {
				status = "passed",
				output = TEMPNAME,
			},
		}

		assert.are.same(expected, results)
	end)

	async.it("builds the results for parameterized test with @CsvSource for maven", function()
		--given
		local runSpec = {
			cwd = current_dir .. "tests/fixtures/maven-demo",
			context = {
				report_file = vim.loop.cwd()
					.. "/tests/fixtures/maven-demo/target/surefire-reports/TEST-com.example.ParameterizedMethodTest.xml",
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
		local expected = {
			[current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ParameterizedMethodTest.java::ParameterizedMethodTest::parameterizedMethodShouldFail"] = {
				errors = {
					{
						message = "parameterizedMethodShouldFail(Integer, Integer)[1] -> org.opentest4j.AssertionFailedError: expected: <true> but was: <false>\nparameterizedMethodShouldFail(Integer, Integer)[2] -> org.opentest4j.AssertionFailedError: expected: <true> but was: <false>",
					},
				},
				short = "parameterizedMethodShouldFail(Integer, Integer)[1] -> org.opentest4j.AssertionFailedError: expected: <true> but was: <false>\nparameterizedMethodShouldFail(Integer, Integer)[2] -> org.opentest4j.AssertionFailedError: expected: <true> but was: <false>",
				status = "failed",
				output = TEMPNAME,
			},
			[current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ParameterizedMethodTest.java::ParameterizedMethodTest::parameterizedMethodShouldNotFail"] = {
				status = "passed",
				output = TEMPNAME,
			},
		}

		assert.are.same(expected, results)
	end)

	async.it("builds the results for parameterized with @EmptySource test", function()
		--given
		local project_dir = project_type == "maven" and "maven-demo" or "gradle-groovy-demo"
		local runSpec = {
			cwd = current_dir .. "tests/fixtures/" .. project_dir,
			context = {
				report_file = vim.loop.cwd()
					.. "/tests/fixtures/maven-demo/target/surefire-reports/TEST-com.example.EmptySourceTest.xml",
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
		local expected = {
			[current_dir .. "tests/fixtures/" .. project_dir .. "/src/test/java/com/example/EmptySourceTest.java::EmptySourceTest::emptySourceShouldFail"] = {
				errors = {
					{
						message = "emptySourceShouldFail(String)[1] -> org.opentest4j.AssertionFailedError: expected: <false> but was: <true>",
					},
				},
				short = "emptySourceShouldFail(String)[1] -> org.opentest4j.AssertionFailedError: expected: <false> but was: <true>",
				status = "failed",
				output = TEMPNAME,
			},
			[current_dir .. "tests/fixtures/" .. project_dir .. "/src/test/java/com/example/EmptySourceTest.java::EmptySourceTest::emptySourceShouldPass"] = {
				status = "passed",
				output = TEMPNAME,
			},
		}

		assert.are.same(expected, results)
	end)
end)
