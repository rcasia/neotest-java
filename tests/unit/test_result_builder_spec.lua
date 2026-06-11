local _ = require("vim.treesitter") -- NOTE: needed for loading treesitter upfront for the tests
local ResultBuilder = require("neotest-java.core.result_builder")
local JunitResult = require("neotest-java.model.junit_result")
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

--- Build a JunitResult from a testcase table shaped the way xml2lua would
--- produce it (with `_attr`, optional `failure` / `error` / `system-out` / `system-err`).
local function jr(testcase)
	return JunitResult:new(testcase, function()
		return TEMPNAME
	end)
end

--- Build a passing testcase (xml2lua shape).
local function passing(name, classname, time)
	return {
		_attr = { name = name, classname = classname or "com.example.ExampleTest", time = time or "0" },
	}
end

--- Build a failing testcase (xml2lua shape, single failure with a body).
local function failing(name, classname, message, type_attr, body)
	return {
		_attr = { name = name, classname = classname or "com.example.ExampleTest", time = "0.001" },
		failure = {
			_attr = { message = message, type = type_attr or "org.opentest4j.AssertionFailedError" },
			body,
		},
	}
end

--- Build a failing testcase with a CDATA-wrapped failure body (the prior bug #296 shape).
local function failing_cdata(name, classname, message, type_attr, cdata_body)
	return {
		_attr = { name = name, classname = classname or "com.example.ExampleTest", time = "0.001" },
		failure = {
			_attr = { message = message, type = type_attr or "org.opentest4j.AssertionFailedError" },
			-- xml2lua puts CDATA contents as a string inside the failure table
			-- (or, for the multi-fragment case, as a nested array)
			cdata_body,
		},
	}
end

--- Build an erroring testcase (xml2lua shape, single error with a body).
local function erroring(name, classname, message, type_attr, body)
	return {
		_attr = { name = name, classname = classname or "com.example.ExampleTest", time = "0.001" },
		error = {
			_attr = { message = message, type = type_attr or "java.lang.RuntimeException" },
			body,
		},
	}
end

local function scan_dir_returning(file_path)
	return function(dir)
		assert(dir == DEFAULT_SPEC.context.reports_dir, "should scan in spec.context.reports_dir")
		return { file_path }
	end
end

local function scan_dir_returning_paths(paths)
	return function(dir)
		assert(dir == DEFAULT_SPEC.context.reports_dir, "should scan in spec.context.reports_dir")
		return paths
	end
end

--- Build a stub JunitResultReader that returns the given JunitResult array.
local function reader_returning(jrs)
	return {
		read_all = function()
			return jrs
		end,
	}
end

describe("ResultBuilder", function()
	local remove_file = function() end
	local fake_tempname = function()
		return TEMPNAME
	end

	it("returns empty when the reader returns empty", function()
		-- given
		local file_path = current_dir .. "tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java"
		local tree = TREES.TWO_TESTS_IN_FILE(Path(file_path))

		-- when
		local result = ResultBuilder({
			scan_dir = scan_dir_returning(Path("any/TEST-someTest.xml")),
			junit_result_reader = reader_returning({}),
			remove_file = remove_file,
			tempname_fn = fake_tempname,
		}).build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree)

		-- then
		eq({}, result)
	end)

	it("should build results from report", function()
		-- given
		local file_path = Path("MyTest.java")
		local tree = TREES.TWO_TESTS_IN_FILE(file_path)
		local jrs = {
			jr(
				failing(
					"firstTestMethod()",
					"com.example.ExampleTest",
					"expected: <true> but was: <false>",
					nil,
					"OUTPUT TEXT"
				)
			),
			jr(passing("secondTestMethod()")),
		}

		-- then
		eq(
			{
				["com.example.ExampleTest#firstTestMethod()"] = {
					errors = { { message = "expected: <true> but was: <false>" } },
					short = "expected: <true> but was: <false>",
					status = "failed",
					output = TEMPNAME,
				},
				["com.example.ExampleTest#secondTestMethod()"] = {
					status = "passed",
					output = TEMPNAME,
				},
			},
			ResultBuilder({
				scan_dir = scan_dir_returning(file_path),
				junit_result_reader = reader_returning(jrs),
				remove_file = remove_file,
				tempname_fn = fake_tempname,
			}).build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree)
		)
	end)

	it("builds failed results when assertion message contains a greater-than character", function()
		-- given
		local file_path = Path("MyTest.java")
		local tree = TREES.TWO_TESTS_IN_FILE(file_path)
		-- The prior bug #296: xml2lua returns the CDATA as a string nested
		-- inside the failure, with the first '>' fragmenting the parser.
		local cdata_body = table.concat({
			"org.opentest4j.AssertionFailedError: expected: <0.2> but was: <0.3>",
			"at com.example.ExampleTest.firstTestMethod(ExampleTest.java:42)",
		}, "\n")
		local jrs = {
			jr(
				failing_cdata(
					"firstTestMethod()",
					"com.example.ExampleTest",
					"expected: <0.2> but was: <0.3>",
					nil,
					cdata_body
				)
			),
		}

		-- then
		eq(
			{
				["com.example.ExampleTest#firstTestMethod()"] = {
					errors = { { message = "expected: <0.2> but was: <0.3>", line = 41 } },
					short = "expected: <0.2> but was: <0.3>",
					status = "failed",
					output = TEMPNAME,
				},
			},
			ResultBuilder({
				scan_dir = scan_dir_returning(file_path),
				junit_result_reader = reader_returning(jrs),
				remove_file = remove_file,
				tempname_fn = fake_tempname,
			}).build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree)
		)
	end)

	it("builds the results for a test that has an error at start", function()
		-- given
		local file_path = Path("MyTest.java")
		local tree = TREES.TWO_TESTS_IN_FILE(file_path)
		local jrs = {
			jr(
				erroring(
					"firstTestMethod()",
					"com.example.ExampleTest",
					"Error creating bean with name 'com.example.ExampleTest': Injection of autowired dependencies failed",
					"org.springframework.beans.factory.BeanCreationException",
					"ERROR OUTPUT TEXT"
				)
			),
			jr(passing("secondTestMethod()")),
		}

		-- then
		eq(
			{
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
			},
			ResultBuilder({
				scan_dir = scan_dir_returning(file_path),
				junit_result_reader = reader_returning(jrs),
				remove_file = remove_file,
				tempname_fn = fake_tempname,
			}).build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree)
		)
	end)

	it("builds results for parameterized test with @CsvSource", function()
		-- given
		local file_path = Path("MyTest.java")
		local tree = TREES.PARAMETERIZED_TEST2
		local jrs = {
			jr(
				failing(
					"parameterizedMethodShouldFail(Integer, Integer)[1]",
					"com.example.ParameterizedMethodTest",
					"expected: <true> but was: <false>",
					nil,
					"FAILURE OUTPUT"
				)
			),
			jr(
				failing(
					"parameterizedMethodShouldFail(Integer, Integer)[2]",
					"com.example.ParameterizedMethodTest",
					"expected: <true> but was: <false>",
					nil,
					"FAILURE OUTPUT"
				)
			),
			jr(
				passing(
					"parameterizedMethodShouldFail(Integer, Integer)[3]",
					"com.example.ParameterizedMethodTest",
					"0.001"
				)
			),
			jr(
				passing(
					"parameterizedMethodShouldNotFail(Integer, Integer, Integer)[1]",
					"com.example.ParameterizedMethodTest",
					"0.001"
				)
			),
			jr(
				passing(
					"parameterizedMethodShouldNotFail(Integer, Integer, Integer)[2]",
					"com.example.ParameterizedMethodTest",
					"0"
				)
			),
			jr(
				passing(
					"parameterizedMethodShouldNotFail(Integer, Integer, Integer)[3]",
					"com.example.ParameterizedMethodTest",
					"0"
				)
			),
			jr(
				passing(
					"parameterizedMethodShouldNotFail(Integer, Integer, Integer)[4]",
					"com.example.ParameterizedMethodTest",
					"0"
				)
			),
		}

		-- then
		eq(
			{
				["com.example.ParameterizedMethodTest#parameterizedMethodShouldFail(java.lang.Integer, java.lang.Integer)"] = {
					errors = {
						{
							message = "parameterizedMethodShouldFail(Integer, Integer)[1] -> expected: <true> but was: <false>",
						},
						{
							message = "parameterizedMethodShouldFail(Integer, Integer)[2] -> expected: <true> but was: <false>",
						},
					},
					short = vim.iter({
						"parameterizedMethodShouldFail(Integer, Integer)[1] -> expected: <true> but was: <false>",
						"parameterizedMethodShouldFail(Integer, Integer)[2] -> expected: <true> but was: <false>",
					}):join("\n"),
					status = "failed",
					output = TEMPNAME,
				},
				["com.example.ParameterizedMethodTest#parameterizedMethodShouldNotFail(java.lang.Integer, java.lang.Integer, java.lang.Integer)"] = {
					status = "passed",
					output = TEMPNAME,
				},
			},
			ResultBuilder({
				scan_dir = scan_dir_returning(file_path),
				junit_result_reader = reader_returning(jrs),
				remove_file = remove_file,
				tempname_fn = fake_tempname,
			}).build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree)
		)
	end)

	it("builds the results for parameterized with @EmptySource test", function()
		-- given
		local file_path = Path("MyTest.java")
		local tree = TREES.PARAMETERIZED_TEST
		local jrs = {
			jr(
				failing(
					"parameterizedMethodShouldFail(Integer, Integer)[1]",
					"com.example.ExampleTest",
					"expected: <false> but was: <true>",
					nil,
					"FAILURE OUTPUT"
				)
			),
			jr(passing("parameterizedMethodShouldFail(Integer, Integer)[2]", "com.example.ExampleTest", "0.001")),
		}

		-- then
		eq(
			{
				["com.example.ExampleTest#parameterizedMethodShouldFail(java.lang.Integer, java.lang.Integer)"] = {
					errors = {
						{
							message = "parameterizedMethodShouldFail(Integer, Integer)[1] -> expected: <false> but was: <true>",
						},
					},
					short = "parameterizedMethodShouldFail(Integer, Integer)[1] -> expected: <false> but was: <true>",
					status = "failed",
					output = TEMPNAME,
				},
			},
			ResultBuilder({
				scan_dir = scan_dir_returning(file_path),
				junit_result_reader = reader_returning(jrs),
				remove_file = remove_file,
				tempname_fn = fake_tempname,
			}).build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree)
		)
	end)

	it("should build results for nested tests", function()
		-- given
		local file_path = Path("MyTest.java")
		local tree = TREES.NESTED_TESTS
		local jrs = {
			jr(passing("someTest()", "com.example.SomeTest$SomeNestedTest$AnotherNestedTest", "0.004")),
			jr(passing("oneMoreOuterTest()", "com.example.SomeTest$SomeNestedTest", "0")),
		}

		-- then
		eq(
			{
				["com.example.SomeTest$SomeNestedTest$AnotherNestedTest#someTest()"] = {
					status = "passed",
					output = TEMPNAME,
				},
				["com.example.SomeTest$SomeNestedTest#oneMoreOuterTest()"] = {
					status = "passed",
					output = TEMPNAME,
				},
			},
			ResultBuilder({
				scan_dir = scan_dir_returning(file_path),
				junit_result_reader = reader_returning(jrs),
				remove_file = remove_file,
				tempname_fn = fake_tempname,
			}).build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree)
		)
	end)

	it("should build results with multiple failures", function()
		-- given
		local file_path = Path("MyTest.java")
		local tree = TREES.TWO_TESTS_IN_FILE(file_path)
		local jrs = {
			jr(
				failing(
					"firstTestMethod()",
					"com.example.ExampleTest",
					"expected: <false> but was: <true>",
					nil,
					"FAILURE OUTPUT"
				)
			),
			-- second testcase has TWO failure children — the second has no message attr,
			-- just a type attr. xml2lua represents this as a table with `_attr.type` only.
			jr({
				_attr = { name = "secondTestMethod()", classname = "com.example.ExampleTest", time = "0.003" },
				failure = {
					{
						_attr = {
							message = "expected: <false> but was: <true>",
							type = "org.opentest4j.AssertionFailedError",
						},
						"FAILURE OUTPUT",
					},
					{
						_attr = { type = "java.lang.StackOverflowError" },
						"FAILURE OUTPUT",
					},
				},
			}),
		}

		-- then
		eq(
			{
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
			},
			ResultBuilder({
				scan_dir = scan_dir_returning(file_path),
				junit_result_reader = reader_returning(jrs),
				remove_file = remove_file,
				tempname_fn = fake_tempname,
			}).build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree)
		)
	end)

	it("should remove report files after processing", function()
		-- given
		local report_file = Path("/tmp/TEST-ExampleTest.xml")
		local removed_files = {}
		local tracking_remove_file = function(filepath)
			table.insert(removed_files, filepath)
			return true
		end
		local file_path = Path("MyTest.java")
		local tree = TREES.TWO_TESTS_IN_FILE(file_path)
		local jrs = {
			jr(
				failing(
					"firstTestMethod()",
					"com.example.ExampleTest",
					"expected: <true> but was: <false>",
					nil,
					"OUTPUT TEXT"
				)
			),
			jr(passing("secondTestMethod()")),
		}

		-- when
		local result = ResultBuilder({
			scan_dir = scan_dir_returning_paths({ report_file }),
			junit_result_reader = reader_returning(jrs),
			remove_file = tracking_remove_file,
			tempname_fn = fake_tempname,
		}).build_results(DEFAULT_SPEC, SUCCESSFUL_RESULT, tree)

		-- then
		eq({
			["com.example.ExampleTest#firstTestMethod()"] = {
				errors = { { message = "expected: <true> but was: <false>" } },
				short = "expected: <true> but was: <false>",
				status = "failed",
				output = TEMPNAME,
			},
			["com.example.ExampleTest#secondTestMethod()"] = {
				status = "passed",
				output = TEMPNAME,
			},
		}, result)
		eq({ report_file:to_string() }, removed_files)
	end)
end)
