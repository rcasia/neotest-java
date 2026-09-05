---@diagnostic disable: undefined-field
local JunitResult = require("neotest-java.model.junit_result")
local ResultStatus = require("neotest.types").ResultStatus
local eq = require("tests.assertions").eq

--- Build a passing testcase (xml2lua shape).
local function passing(name, classname)
	return {
		_attr = { name = name, classname = classname or "com.example.ExampleTest", time = "0" },
	}
end

--- Build a failing testcase (xml2lua shape, single failure with a body).
local function failing(name, classname, message, body)
	return {
		_attr = { name = name, classname = classname or "com.example.ExampleTest", time = "0.001" },
		failure = {
			_attr = { message = message, type = "org.opentest4j.AssertionFailedError" },
			body,
		},
	}
end

describe("JunitResult", function()
	describe("id/name/classname", function()
		it("builds the id from classname and name", function()
			local jres = JunitResult:new(passing("shouldWork()", "com.example.Foo"))
			eq("com.example.Foo#shouldWork()", jres:id())
		end)

		it("strips the parameterized-test iteration suffix from id", function()
			local jres = JunitResult:new(passing("shouldWork(int)[1]", "com.example.Foo"))
			eq("com.example.Foo#shouldWork(int)", jres:id())
		end)

		it("exposes name and classname directly from the testcase", function()
			local jres = JunitResult:new(passing("shouldWork()", "com.example.Foo"))
			eq("shouldWork()", jres:name())
			eq("com.example.Foo", jres:classname())
		end)
	end)

	describe("status", function()
		it("is PASSED with no failures for a testcase with no failure/error node", function()
			local status, failures = JunitResult:new(passing("a()")):status()
			eq(ResultStatus.passed, status)
			eq({}, failures)
		end)

		it("is FAILED with the parsed failure for a testcase with a failure node", function()
			local status, failures = JunitResult:new(failing("a()", nil, "expected true", "stack")):status()
			eq(ResultStatus.failed, status)
			eq(1, #failures)
			eq("expected true", failures[1].failure_message)
		end)
	end)

	describe("errors", function()
		it("returns nil when passed (no errors to report)", function()
			local jres = JunitResult:new(passing("a()"))
			eq(nil, jres:errors())
		end)

		it("returns one neotest.Error per failure, with the line scraped from the stack trace", function()
			local body = "org.opentest4j.AssertionFailedError: expected true\n" .. "at com.example.Foo.a(Foo.java:42)"
			local jres = JunitResult:new(failing("a()", "com.example.Foo", "expected true", body))

			local errors = jres:errors()

			eq({ { message = "expected true", line = 41 } }, errors)
		end)

		it("prefixes the message with the test name when with_name_prefix is true", function()
			local jres = JunitResult:new(failing("a()", nil, "expected true", "stack"))
			local errors = jres:errors(true)
			assert(errors, "errors should not be nil for a failed testcase")
			eq("a() -> expected true", errors[1].message)
		end)
	end)

	describe("output", function()
		it("is a single 'Test passed' line when passed", function()
			local jres = JunitResult:new(passing("a()"))
			eq({ "Test passed\n" }, jres:output())
		end)

		it("includes the raw failure output (stack trace) when failed", function()
			local jres = JunitResult:new(failing("a()", nil, "expected true", "stack trace here"))
			eq({ "stack trace here", "\n" }, jres:output())
		end)
	end)

	describe("result()", function()
		it("returns exactly {status, output_lines, errors, short} for a failed testcase", function()
			local jres = JunitResult:new(failing("a()", nil, "expected true", "stack"))

			eq({
				status = ResultStatus.failed,
				output_lines = jres:output(),
				errors = jres:errors(),
				short = "expected true",
			}, jres:result())
		end)

		it("omits short/errors when passed, but still includes output_lines", function()
			local jres = JunitResult:new(passing("a()"))

			eq({
				status = ResultStatus.passed,
				output_lines = jres:output(),
			}, jres:result())
		end)
	end)

	describe("SKIPPED / ERROR (static results, no testcase involved)", function()
		it("SKIPPED is a skipped result explaining the test didn't run", function()
			eq({
				status = ResultStatus.skipped,
				output_lines = { "com.example.Foo#a()", "This test was not executed." },
			}, JunitResult.SKIPPED("com.example.Foo#a()"))
		end)

		it("ERROR uses the given output verbatim when provided", function()
			eq({
				status = "failed",
				output_lines = "boom output",
			}, JunitResult.ERROR("com.example.Foo#a()", "boom output"))
		end)

		it("ERROR falls back to an explanatory message when no output is given", function()
			eq({
				status = "failed",
				output_lines = { "com.example.Foo#a()", "This test execution had an unexpected error." },
			}, JunitResult.ERROR("com.example.Foo#a()"))
		end)
	end)

	describe("merge_results() — combining parameterized-test iterations", function()
		it("is PASSED, with every iteration's output concatenated, when all iterations pass", function()
			local a = JunitResult:new(passing("a(int)[2]"))
			local b = JunitResult:new(passing("a(int)[1]"))

			local data = JunitResult.merge_results({ a, b })

			eq(ResultStatus.passed, data.status)
			eq(nil, data.errors)
			-- sorted by name: [1] before [2]
			local expected_output = {}
			vim.list_extend(expected_output, b:output())
			vim.list_extend(expected_output, a:output())
			eq(expected_output, data.output_lines)
		end)

		it("is FAILED as a whole when any single iteration fails", function()
			local a = JunitResult:new(passing("a(int)[1]"))
			local b = JunitResult:new(failing("a(int)[2]", nil, "expected true", "stack"))

			local data = JunitResult.merge_results({ a, b })

			eq(ResultStatus.failed, data.status)
			eq(1, #data.errors)
			eq("a(int)[2] -> expected true", data.errors[1].message)
		end)
	end)
end)
