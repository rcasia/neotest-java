local test_parser = require("neotest-java.util.test_parser")
local async = require("nio").tests

describe("test_parser", function()
	describe("should not have errors while reading html reports generated in gradle projects", function()
		local cwd = vim.fn.getcwd()
		local _test_reports =
			vim.fn.globpath(cwd .. "/tests/fixtures", "gradle*/build/reports/tests/test/classes/*.html", true)

		local test_reports = vim.split(_test_reports, "\n")
		for _, test_report in ipairs(test_reports) do
			async.it("should be able to read test report: " .. test_report, function()
				test_parser.parse_html_gradle_report(test_report)
			end)
		end
	end)

	async.it("should parse a parameterized test result from html from gradle", function()
		-- given
		local filename = vim.fn.getcwd() .. "/tests/fixtures/com.example.ParameterizedTests.html"

		-- when
		local actual = test_parser.parse_html_gradle_report(filename)

		-- then
		local expected = {
			["com.example.ParameterizedTests::shouldFail"] = {
				status = "failed",
				{
					name = "shouldFail(int, int, int)[1]",
					status = "failed",
					classname = "com.example.ParameterizedTests",
					message = "org.opentest4j.AssertionFailedError: expected: <true> but was: <false>",
				},
				{
					name = "shouldFail(int, int, int)[2]",
					status = "failed",
					classname = "com.example.ParameterizedTests",
					message = "org.opentest4j.AssertionFailedError: expected: <true> but was: <false>",
				},
				{
					name = "shouldFail(int, int, int)[3]",
					status = "failed",
					classname = "com.example.ParameterizedTests",
					message = "org.opentest4j.AssertionFailedError: expected: <true> but was: <false>",
				},
			},
			["com.example.ParameterizedTests::shouldPass"] = {
				status = "passed",
				{
					name = "shouldPass(int, int, int)[1]",
					status = "passed",
					classname = "com.example.ParameterizedTests",
					message = nil,
				},
				{
					name = "shouldPass(int, int, int)[2]",
					status = "passed",
					classname = "com.example.ParameterizedTests",
					message = nil,
				},
				{
					name = "shouldPass(int, int, int)[3]",
					status = "passed",
					classname = "com.example.ParameterizedTests",
					message = nil,
				},
			},
		}

		assert.are.same(expected, actual)
	end)

	async.it("should parse a parameterized test result from html from gradle 2", function()
		-- given
		local filename = vim.fn.getcwd() .. "/tests/fixtures/com.example.SimpleTest.html"

		-- when
		local actual = test_parser.parse_html_gradle_report(filename)

		-- then
		local expected = {
			["com.example.SimpleTest::shouldPass"] = {
				status = "passed",
				{
					name = "shouldPass(int, int, int)[1]",
					status = "passed",
					classname = "com.example.SimpleTest",
					message = nil,
				},
				{
					name = "shouldPass(int, int, int)[2]",
					status = "passed",
					classname = "com.example.SimpleTest",
					message = nil,
				},
				{
					name = "shouldPass(int, int, int)[3]",
					status = "passed",
					classname = "com.example.SimpleTest",
					message = nil,
				},
			},
		}

		assert.are.same(expected, actual)
	end)

	async.it("should parse a parameterized test result from html with one single failing test", function()
		-- given
		local filename = vim.fn.getcwd() .. "/tests/fixtures/com.example.SimpleTest3.html"

		-- when
		local actual = test_parser.parse_html_gradle_report(filename)

		-- then
		local expected = {
			["com.example.SimpleTest3::shouldFail"] = {
				status = "failed",
				{
					name = "shouldFail(int, int)[1]",
					status = "failed",
					message = "org.opentest4j.AssertionFailedError: expected: <true> but was: <false>",
					classname = "com.example.SimpleTest3",
				},
			},
		}

		assert.are.same(expected, actual)
	end)

	for _, filepath in ipairs({
		"tests/fixtures/report-with-no-parameterized-test-1.html",
		"tests/fixtures/report-with-no-parameterized-test-2.html",
	}) do
		async.it("should return empty object when it has no parameterized test: " .. filepath, function()
			-- given
			local absolute_filepath = vim.fn.getcwd() .. "/" .. filepath

			-- when
			local actual = test_parser.parse_html_gradle_report(absolute_filepath)

			-- then
			local expected = {}

			assert.are.same(expected, actual)
		end)
	end
end)
