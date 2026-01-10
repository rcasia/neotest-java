local _ = require("vim.treesitter") -- NOTE: needed for loading treesitter upfront for the tests
local async = require("nio").tests
local plugin = require("neotest-java")
local result_builder = require("neotest-java.core.result_builder")
local tempname_fn = require("nio").fn.tempname
local Path = require("neotest-java.model.path")
local eq = require("tests.assertions").eq
local TREES = require("tests.trees")

local current_dir = vim.fn.fnamemodify(vim.fn.expand("%:p:h"), ":p")

local TEMPDIR = os.getenv("TEMP") or os.getenv("TMP") or vim.uv.os_tmpdir()
local TEMPNAME = TEMPDIR .. "/neotest-java-result-builder-test.txt"

local SUCCESSFUL_RESULT = {
	code = 0,
	output = "output",
}

local DEFAULT_SPEC = {
	context = {
		reports_dir = Path("tests/fixtures/maven-demo/target/surefire-reports/"),
	},
}

local tempfiles = {}

---@param content string
---@return neotest-java.Path filepath
local function create_tempfile_with_test(content)
	local path = vim.fn.tempname() .. ".java"
	table.insert(tempfiles, path)
	local file = assert(io.open(path, "w"))
	file:write(content)
	file:close()
	return Path(path)
end

describe("ResultBuilder", function()
	async.before_each(function()
		-- mock the tempname function to return a fixed value
		require("nio").fn.tempname = function()
			return TEMPNAME
		end
	end)

	async.after_each(function()
		require("nio").fn.tempname = tempname_fn

		-- remove all temp files
		for _, path in ipairs(tempfiles) do
			os.remove(path)
		end
	end)

	async.it("ignores report file when cannot be read", function()
		--given
		local scan_dir = function(dir)
			assert(dir == DEFAULT_SPEC.context.reports_dir, "should scan in spec.context.reports_dir")
			return { "TEST-someTest.xml" }
		end
		local read_file = function()
			error("cannot read file")
		end

		local file_path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java"
		local tree = TREES.TWO_TESTS_IN_FILE(Path(file_path))

		local expected = {
			-- ["com.example.ExampleTest#firstTestMethod()"] = {
			-- 	status = "skipped",
			-- 	output = TEMPNAME,
			-- },
			-- ["com.example.ExampleTest#secondTestMethod()"] = {
			-- 	status = "skipped",
			-- 	output = TEMPNAME,
			-- },
		}
		--when
		local results = result_builder.build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree, scan_dir, read_file)

		-- then
		assert.are.same(expected, results)
	end)

	async.it("should build results from report", function()
		--given
		local file_path = Path("MyTest.java")
		local report_file = [[
				<testsuite>
					<testcase name="firstTestMethod()" classname="com.example.ExampleTest" time="0.001">
						<failure message="expected: &lt;true&gt; but was: &lt;false&gt;" type="org.opentest4j.AssertionFailedError">
							OUTPUT TEXT
						</failure>
					</testcase>
					<testcase name="secondTestMethod()" classname="com.example.ExampleTest" time="0"/>
				</testsuite>
		]]

		local tree = TREES.TWO_TESTS_IN_FILE(file_path)
		local scan_dir = function(dir)
			assert(dir == DEFAULT_SPEC.context.reports_dir, "should scan in spec.context.reports_dir")
			return { file_path }
		end
		local read_file = function()
			return report_file
		end

		local expected = {
			["com.example.ExampleTest#firstTestMethod()"] = {
				-- errors = { { line = 13, message = "expected: <true> but was: <false>" } },
				errors = { { message = "expected: <true> but was: <false>" } },
				short = "expected: <true> but was: <false>",
				status = "failed",
				output = TEMPNAME,
			},
			["com.example.ExampleTest#secondTestMethod()"] = {
				status = "passed",
				output = TEMPNAME,
			},
		}

		--when
		local results = result_builder.build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree, scan_dir, read_file)

		--then
		eq(expected, results)
	end)

	async.it("builds the results for a test that has an error at start", function()
		--given
		local report_file = [[
				<testsuite>
					<testcase name="firstTestMethod()" classname="com.example.ExampleTest" time="0.001">
						<error message="Error creating bean with name &apos;com.example.ExampleTest&apos;: Injection of autowired dependencies failed" type="org.springframework.beans.factory.BeanCreationException">
							ERROR OUTPUT TEXT
						</error>
						<system-out>
							SYSTEM OUTPUT TEXT
						</system-out>
					</testcase>
					<testcase name="secondTestMethod()" classname="com.example.ExampleTest" time="0"/>
				</testsuite>
			]]

		local file_path = Path("MyTest.java")
		local tree = TREES.TWO_TESTS_IN_FILE(file_path)
		local scan_dir = function(dir)
			assert(dir == DEFAULT_SPEC.context.reports_dir, "should scan in spec.context.reports_dir")
			return { file_path }
		end
		local read_file = function()
			return report_file
		end

		local expected = {
			["com.example.ExampleTest#firstTestMethod()"] = {
				errors = {
					{
						message = "Error creating bean with name 'com.example.ExampleTest': Injection of autowired dependencies failed",
					},
				},
				output = TEMPNAME,
				short = "Error creating bean with name 'com.example.ExampleTest': Injection of autowired dependencies failed",
				status = "failed",
			},
			["com.example.ExampleTest#secondTestMethod()"] = {
				status = "passed",
				output = TEMPNAME,
			},
		}

		--when
		local results = result_builder.build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree, scan_dir, read_file)

		--then
		eq(expected, results)
	end)

	async.it("builds results for parameterized test with @CsvSource", function()
		--given
		local report_file = [[
				<testsuite>
					<testcase name="parameterizedMethodShouldFail(Integer, Integer)[1]" classname="com.example.ParameterizedMethodTest" time="0.001">
						<failure message="expected: &lt;true&gt; but was: &lt;false&gt;" type="org.opentest4j.AssertionFailedError">
							FAILURE OUTPUT
						</failure>
					</testcase>
					<testcase name="parameterizedMethodShouldFail(Integer, Integer)[2]" classname="com.example.ParameterizedMethodTest" time="0.001">
						<failure message="expected: &lt;true&gt; but was: &lt;false&gt;" type="org.opentest4j.AssertionFailedError">
							FAILURE OUTPUT
						</failure>
					</testcase>
					<testcase name="parameterizedMethodShouldFail(Integer, Integer)[3]" classname="com.example.ParameterizedMethodTest" time="0.001"/>
					<testcase name="parameterizedMethodShouldNotFail(Integer, Integer, Integer)[1]" classname="com.example.ParameterizedMethodTest" time="0.001"/>
					<testcase name="parameterizedMethodShouldNotFail(Integer, Integer, Integer)[2]" classname="com.example.ParameterizedMethodTest" time="0"/>
					<testcase name="parameterizedMethodShouldNotFail(Integer, Integer, Integer)[3]" classname="com.example.ParameterizedMethodTest" time="0"/>
					<testcase name="parameterizedMethodShouldNotFail(Integer, Integer, Integer)[4]" classname="com.example.ParameterizedMethodTest" time="0"/>
				</testsuite>
			]]

		local file_path = Path("MyTest.java")

		local tree = TREES.PARAMETERIZED_TEST
		local scan_dir = function(dir)
			assert(dir == DEFAULT_SPEC.context.reports_dir, "should scan in spec.context.reports_dir")
			return { file_path }
		end
		local read_file = function()
			return report_file
		end

		local expected = {
			["com.example.ParameterizedMethodTest#parameterizedMethodShouldFail(java.lang.Integer, java.lang.Integer)"] = {
				errors = {
					{
						-- line = 27,
						message = "parameterizedMethodShouldFail(Integer, Integer)[1] -> expected: <true> but was: <false>",
					},
					{
						-- line = 27,
						message = "parameterizedMethodShouldFail(Integer, Integer)[2] -> expected: <true> but was: <false>",
					},
				},
				short = "parameterizedMethodShouldFail(Integer, Integer)[1] -> expected: <true> but was: <false>\nparameterizedMethodShouldFail(Integer, Integer)[2] -> expected: <true> but was: <false>",
				status = "failed",
				output = TEMPNAME,
			},
			-- ["com.example.ParameterizedMethodTest#parameterizedMethodShouldNotFail(java.lang.Integer, java.lang.Integer, java.lang.Integer)"] = {
			-- 	status = "passed",
			-- 	output = TEMPNAME,
			-- },
		}
		--when
		local results = result_builder.build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree, scan_dir, read_file)

		--then
		eq(expected, results)
	end)

	async.it("builds the results for parameterized with @EmptySource test", function()
		--given
		local report_file = [[
				<testsuite>
					<testcase name="parameterizedMethodShouldFail(Integer)[1]" classname="com.example.ExampleTest" time="0.003">
						<failure message="expected: &lt;false&gt; but was: &lt;true&gt;" type="org.opentest4j.AssertionFailedError">
							FAILURE OUTPUT
						</failure>
					</testcase>
					<testcase name="parameterizedMethodShouldFail(Integer)[2]" classname="com.example.ExampleTest" time="0.001"/>
				</testsuite>
			]]

		local file_path = Path("MyTest.java")

		local tree = TREES.PARAMETERIZED_TEST
		local scan_dir = function(dir)
			assert(dir == DEFAULT_SPEC.context.reports_dir, "should scan in spec.context.reports_dir")
			return { file_path }
		end
		local read_file = function()
			return report_file
		end

		local expected = {
			["com.example.ExampleTest#parameterizedMethodShouldFail(Integer)"] = {
				errors = {
					{
						-- line = 22,
						message = "parameterizedMethodShouldFail(Integer)[1] -> expected: <false> but was: <true>",
					},
				},
				short = "parameterizedMethodShouldFail(Integer)[1] -> expected: <false> but was: <true>",
				status = "failed",
				output = TEMPNAME,
			},
		}
		--when
		local results = result_builder.build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree, scan_dir, read_file)

		--then
		eq(expected, results)
	end)

	async.it("should build results for nested tests", function()
		local report_file = [[
				<testsuite>
					<testcase name="someTest()" classname="com.example.SomeTest$SomeNestedTest$AnotherNestedTest" time="0.004">
						<system-out></system-out>
					</testcase>
					<testcase name="oneMoreOuterTest()" classname="com.example.SomeTest$SomeNestedTest" time="0">
						<system-out></system-out>
					</testcase>
				</testsuite>
			]]

		local file_path = Path("MyTest.java")

		local tree = TREES.NESTED_TESTS
		local scan_dir = function(dir)
			assert(dir == DEFAULT_SPEC.context.reports_dir, "should scan in spec.context.reports_dir")
			return { file_path }
		end
		local read_file = function()
			return report_file
		end

		local expected = {
			["com.example.SomeTest$SomeNestedTest$AnotherNestedTest#someTest()"] = {
				status = "passed",
				output = TEMPNAME,
			},
			["com.example.SomeTest$SomeNestedTest#oneMoreOuterTest()"] = {
				status = "passed",
				output = TEMPNAME,
			},
		}

		--when
		local results = result_builder.build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree, scan_dir, read_file)

		--then
		eq(expected, results)
	end)

	async.it("should build results with multiple failures", function()
		local report_file = [[
				<testsuite>
					<testcase name="firstTestMethod()" classname="com.example.ExampleTest" time="0.003">
						<failure message="expected: &lt;false&gt; but was: &lt;true&gt;" type="org.opentest4j.AssertionFailedError">
							FAILURE OUTPUT
						</failure>
					</testcase>
					<testcase name="secondTestMethod()" classname="com.example.ExampleTest" time="0.003">
						<failure message="expected: &lt;false&gt; but was: &lt;true&gt;" type="org.opentest4j.AssertionFailedError">
							FAILURE OUTPUT
						</failure>
						<failure type="java.lang.StackOverflowError">
							FAILURE OUTPUT
						</failure>
					</testcase>
				</testsuite>
			]]

		local file_path = Path("MyTest.java")

		local tree = TREES.TWO_TESTS_IN_FILE(file_path)
		local scan_dir = function(dir)
			assert(dir == DEFAULT_SPEC.context.reports_dir, "should scan in spec.context.reports_dir")
			return { file_path }
		end
		local read_file = function()
			return report_file
		end

		local expected = {
			["com.example.ExampleTest#firstTestMethod()"] = {
				errors = { { message = "expected: <false> but was: <true>" } },
				short = "expected: <false> but was: <true>",
				status = "failed",
				output = TEMPNAME,
			},
			["com.example.ExampleTest#secondTestMethod()"] = {
				errors = {
					{ message = "expected: <false> but was: <true>" },
					{ message = "java.lang.StackOverflowError" },
				},
				short = "expected: <false> but was: <true>\njava.lang.StackOverflowError",
				status = "failed",
				output = TEMPNAME,
			},
		}

		--when
		local results = result_builder.build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree, scan_dir, read_file)

		--then
		eq(expected, results)
	end)
end)
