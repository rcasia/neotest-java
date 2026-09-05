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
		it("delegates to junit_status.derive", function()
			local status = (JunitResult:new(passing("a()")):status())
			eq(ResultStatus.passed, status)
		end)
	end)

	describe("errors", function()
		it("returns nil when passed", function()
			local jres = JunitResult:new(passing("a()"))
			eq(nil, jres:errors())
		end)

		it("returns the failure message and line for a failed testcase", function()
			local jres = JunitResult:new(failing("a()", nil, "expected true", "stack"))
			local errors = jres:errors()
			eq(1, #errors)
			eq("expected true", errors[1].message)
		end)

		it("prefixes the failure message with the test name when requested", function()
			local jres = JunitResult:new(failing("a()", nil, "expected true", "stack"))
			local errors = jres:errors(true)
			eq("a() -> expected true", errors[1].message)
		end)
	end)

	describe("output", function()
		it("returns a single 'Test passed' line when passed", function()
			local jres = JunitResult:new(passing("a()"))
			eq({ "Test passed\n" }, jres:output())
		end)

		it("returns the failure output when failed", function()
			local jres = JunitResult:new(failing("a()", nil, "expected true", "stack trace here"))
			local output = jres:output()
			assert(
				vim.iter(output):any(function(l)
					return l == "stack trace here"
				end),
				"should include the failure output"
			)
		end)
	end)

	describe("result — plain data, no I/O", function()
		it("returns status/output_lines/errors/short without touching disk", function()
			local jres = JunitResult:new(failing("a()", nil, "expected true", "stack"))

			local data = jres:result()

			eq(ResultStatus.failed, data.status)
			eq("table", type(data.output_lines))
			eq(1, #data.errors)
			eq("expected true", data.short)
			-- crucially: no `output` filepath field — that's OutputWriter's job
			eq(nil, data.output)
		end)

		it("omits short/errors when passed", function()
			local jres = JunitResult:new(passing("a()"))

			local data = jres:result()

			eq(ResultStatus.passed, data.status)
			eq(nil, data.short)
			eq(nil, data.errors)
		end)
	end)

	describe("SKIPPED / ERROR static results", function()
		it("SKIPPED returns skipped status and explanatory output_lines", function()
			local data = JunitResult.SKIPPED("com.example.Foo#a()")
			eq(ResultStatus.skipped, data.status)
			eq({ "com.example.Foo#a()", "This test was not executed." }, data.output_lines)
		end)

		it("ERROR returns failed status with the given output when provided", function()
			local data = JunitResult.ERROR("com.example.Foo#a()", "boom output")
			eq("failed", data.status)
			eq("boom output", data.output_lines)
		end)

		it("ERROR falls back to explanatory output_lines when no output given", function()
			local data = JunitResult.ERROR("com.example.Foo#a()")
			eq("failed", data.status)
			eq({ "com.example.Foo#a()", "This test execution had an unexpected error." }, data.output_lines)
		end)
	end)

	describe("merge_results — plain data, no I/O", function()
		it("merges multiple parameterized-test iterations into one passed result", function()
			local results = {
				JunitResult:new(passing("a(int)[2]")),
				JunitResult:new(passing("a(int)[1]")),
			}

			local data = JunitResult.merge_results(results)

			eq(ResultStatus.passed, data.status)
			eq(nil, data.output)
		end)

		it("marks the merged result failed if any iteration failed", function()
			local results = {
				JunitResult:new(passing("a(int)[1]")),
				JunitResult:new(failing("a(int)[2]", nil, "expected true", "stack")),
			}

			local data = JunitResult.merge_results(results)

			eq(ResultStatus.failed, data.status)
			eq(1, #data.errors)
		end)
	end)
end)
