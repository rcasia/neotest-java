---@diagnostic disable: undefined-field
local junit_failure = require("neotest-java.model.junit_failure")
local eq = require("tests.assertions").eq

describe("junit_failure", function()
	describe("from_node", function()
		it("parses a scalar node", function()
			local failure = junit_failure.from_node("boom")
			eq(failure.failure_message, "boom")
			eq(failure.failure_output, "boom")
		end)

		it("uses the first line as message when it has no type prefix", function()
			local failure = junit_failure.from_node("assertion failed\nsome stack trace")
			eq(failure.failure_message, "assertion failed")
			eq(failure.failure_output, "assertion failed\nsome stack trace")
		end)

		it("strips a leading `Type:` prefix from the first line", function()
			local failure =
				junit_failure.from_node("org.opentest4j.AssertionFailedError: expected <1> but was <2>\nstack")
			eq(failure.failure_message, "expected <1> but was <2>")
		end)

		it("parses a node with an _attr table (message present)", function()
			local node = {
				_attr = { message = "expected: <1> but was: <2>", type = "org.opentest4j.AssertionFailedError" },
				"stacktrace here",
			}
			local failure = junit_failure.from_node(node)
			eq(failure.failure_message, "expected: <1> but was: <2>")
			eq(failure.failure_output, "stacktrace here")
		end)

		it("falls back to the type attribute when message is missing", function()
			local node = { _attr = { type = "java.lang.AssertionError" } }
			local failure = junit_failure.from_node(node)
			eq(failure.failure_message, "java.lang.AssertionError")
		end)

		it("falls back to '<unknown failure>' when neither message nor type is present", function()
			local node = { _attr = {} }
			local failure = junit_failure.from_node(node)
			eq(failure.failure_message, "<unknown failure>")
		end)

		it("parses an array-like node without _attr (xml parser quirk)", function()
			-- Simulates the case where the xml parser breaks on the first '>'
			-- inside the message attribute and produces an array-like node.
			local node = {
				'type="org.opentest4j.AssertionFailedError',
				"full stack trace output",
			}
			local failure = junit_failure.from_node(node)
			eq(failure.failure_message, "full stack trace output")
			eq(failure.failure_output, "full stack trace output")
		end)
	end)

	describe("line_number", function()
		it("returns nil when there is no failure output", function()
			eq(junit_failure.line_number(nil, "com.example.ExampleTest"), nil)
		end)

		it("extracts a 0-indexed line number matching the classname's simple name", function()
			local output = "at com.example.ExampleTest.someTest(ExampleTest.java:42)"
			eq(junit_failure.line_number(output, "com.example.ExampleTest"), 41)
		end)

		it("returns nil when the output does not reference the test file", function()
			local output = "at some.other.Class.method(Other.java:10)"
			eq(junit_failure.line_number(output, "com.example.ExampleTest"), nil)
		end)
	end)
end)
