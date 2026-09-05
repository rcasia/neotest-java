---@diagnostic disable: undefined-field
local junit_status = require("neotest-java.model.junit_status")
local ResultStatus = require("neotest.types").ResultStatus
local eq = require("tests.assertions").eq

describe("junit_status", function()
	describe("derive", function()
		it("returns PASSED with no failures when the testcase has no failure/error", function()
			local status, failures = junit_status.derive({ _attr = { name = "test" } })
			eq(status, ResultStatus.passed)
			eq(failures, {})
		end)

		it("returns FAILED for a single failure node with _attr", function()
			local testcase = {
				failure = { _attr = { message = "boom" }, "stacktrace" },
			}
			local status, failures = junit_status.derive(testcase)
			eq(status, ResultStatus.failed)
			eq(#failures, 1)
			eq(failures[1].failure_message, "boom")
		end)

		it("returns FAILED for a single error node with _attr", function()
			local testcase = {
				error = { _attr = { message = "boom" }, "stacktrace" },
			}
			local status, failures = junit_status.derive(testcase)
			eq(status, ResultStatus.failed)
			eq(#failures, 1)
		end)

		it("returns FAILED with multiple failures for an array-like failure node (parameterized test)", function()
			local testcase = {
				failure = {
					{ _attr = { message = "first" } },
					{ _attr = { message = "second" } },
				},
			}
			local status, failures = junit_status.derive(testcase)
			eq(status, ResultStatus.failed)
			eq(#failures, 2)
			eq(failures[1].failure_message, "first")
			eq(failures[2].failure_message, "second")
		end)

		it("returns FAILED for a scalar failure node inside an array-like table", function()
			local testcase = { failure = { "boom" } }
			local status, failures = junit_status.derive(testcase)
			eq(status, ResultStatus.failed)
			eq(#failures, 1)
			eq(failures[1].failure_message, "boom")
		end)
	end)
end)
