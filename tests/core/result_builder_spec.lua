local async = require("nio").tests
local plugin = require("neotest-java")
local result_builder = require("neotest-java.core.result_builder")
local tempname_fn = require("nio").fn.tempname

local current_dir = vim.fn.fnamemodify(vim.fn.expand("%:p:h"), ":p")
local TEMPNAME = "/tmp/tempname-1234"
local MAVEN_REPORTS_DIR = vim.loop.cwd() .. "/tests/fixtures/maven-demo/target/surefire-reports/"

local GRADLE_REPORTS_DIR = vim.loop.cwd() .. "/tests/fixtures/gradle-groovy-demo/build/test-results/test"

local SUCCESSFUL_RESULT = {
	code = 0,
	output = "output",
}

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

	async.it("throws error when no report files found", function()
		--given
		local scan_dir = function()
			return {}
		end

		local runSpec = {
			cwd = vim.loop.cwd() .. "/tests/fixtures/maven-demo",
			context = {
				reports_dir = MAVEN_REPORTS_DIR,
			},
		}

		local file_path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local _, err = pcall(result_builder.build_results, runSpec, SUCCESSFUL_RESULT, tree, scan_dir)

		-- then
		assert.match("no report file could be generated", err)
	end)

	async.it("ignores report file when cannot be read", function()
		--given
		local scan_dir = function()
			return { "TEST-someTest.xml" }
		end
		local read_file = function()
			error("cannot read file")
		end

		local runSpec = {
			cwd = vim.loop.cwd() .. "/tests/fixtures/maven-demo",
			context = {
				reports_dir = MAVEN_REPORTS_DIR,
			},
		}

		local file_path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java"
		local tree = plugin.discover_positions(file_path)

		local expected = {
			[current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java::ExampleTest::shouldFail"] = {
				status = "skipped",
				output = TEMPNAME,
			},
			[current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java::ExampleTest::shouldNotFail"] = {
				status = "skipped",
				output = TEMPNAME,
			},
		}
		--when
		local results = result_builder.build_results(runSpec, SUCCESSFUL_RESULT, tree, scan_dir, read_file)

		-- then
		assert.are.same(expected, results)
	end)

	async.it("builds the results for maven", function()
		--given
		local scan_dir = function()
			return {}
		end
		local runSpec = {
			cwd = vim.loop.cwd() .. "/tests/fixtures/maven-demo",
			context = {
				reports_dir = MAVEN_REPORTS_DIR,
			},
		}

		local file_path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = result_builder.build_results(runSpec, SUCCESSFUL_RESULT, tree, scan_dir)

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
				reports_dir = MAVEN_REPORTS_DIR,
			},
		}

		local file_path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ErroneousTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, SUCCESSFUL_RESULT, tree)

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
				reports_dir = GRADLE_REPORTS_DIR,
			},
		}

		local file_path = current_dir .. "tests/fixtures/gradle-groovy-demo/src/test/java/com/example/ExampleTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, SUCCESSFUL_RESULT, tree)

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
				reports_dir = GRADLE_REPORTS_DIR,
			},
		}

		local file_path = current_dir
			.. "tests/fixtures/gradle-groovy-demo/src/test/java/com/example/SingleMethodFailingTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, SUCCESSFUL_RESULT, tree)

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
				reports_dir = MAVEN_REPORTS_DIR,
			},
		}

		local file_path = current_dir
			.. "tests/fixtures/maven-demo/src/test/java/com/example/SingleMethodFailingTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, SUCCESSFUL_RESULT, tree)

		--then
		local expected = {
			[current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/SingleMethodFailingTest.java::SingleMethodFailingTest::shouldFail"] = {
				errors = {
					{ line = 9, message = "expected: <true> but was: <false>" },
				},
				short = "expected: <true> but was: <false>",
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
				reports_dir = MAVEN_REPORTS_DIR,
			},
		}

		local file_path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/demo/RepositoryIT.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, SUCCESSFUL_RESULT, tree)

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
				reports_dir = MAVEN_REPORTS_DIR,
			},
		}

		local file_path = current_dir
			.. "tests/fixtures/maven-demo/src/test/java/com/example/ParameterizedMethodTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, SUCCESSFUL_RESULT, tree)

		--then
		local expected = {
			[current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ParameterizedMethodTest.java::ParameterizedMethodTest::parameterizedMethodShouldFail"] = {
				errors = {
					-- {
					-- 	line = 27,
					-- 	message = "expected: <true> but was: <false>",
					-- },
					-- {
					-- 	line = 27,
					-- 	message = "expected: <true> but was: <false>",
					-- },
					{
						line = 27,
						message = "parameterizedMethodShouldFail(Integer, Integer)[1] -> expected: <true> but was: <false>",
					},
					{
						line = 27,
						message = "parameterizedMethodShouldFail(Integer, Integer)[2] -> expected: <true> but was: <false>",
					},
				},
				short = "parameterizedMethodShouldFail(Integer, Integer)[1] -> expected: <true> but was: <false>\nparameterizedMethodShouldFail(Integer, Integer)[2] -> expected: <true> but was: <false>",
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
		local project_dir = "gradle-groovy-demo"
		local runSpec = {
			cwd = current_dir .. "tests/fixtures/" .. project_dir,
			context = {
				reports_dir = MAVEN_REPORTS_DIR,
			},
		}

		local file_path = current_dir
			.. "tests/fixtures/"
			.. project_dir
			.. "/src/test/java/com/example/EmptySourceTest.java"
		local tree = plugin.discover_positions(file_path)

		--when
		local results = plugin.results(runSpec, SUCCESSFUL_RESULT, tree)

		--then
		local expected = {
			[current_dir .. "tests/fixtures/" .. project_dir .. "/src/test/java/com/example/EmptySourceTest.java::EmptySourceTest::emptySourceShouldFail"] = {
				errors = {
					{
						line = 22,
						message = "emptySourceShouldFail(String)[1] -> expected: <false> but was: <true>",
					},
				},
				short = "emptySourceShouldFail(String)[1] -> expected: <false> but was: <true>",
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
