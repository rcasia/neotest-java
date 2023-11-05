local test_parser = require("neotest-java.util.test_parser")

describe("test_parser", function()
	it("should parse a parameterized test result from html from gradle", function()
		-- given
		local filename = vim.fn.getcwd() .. "/tests/fixtures/com.example.ParameterizedTests.html"

		-- when
		local actual = test_parser.parse_html_gradle_report(filename)

		-- then
		local expected = {
			["shouldFail"] = {
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
			["shouldPass"] = {
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

	it("should parse a parameterized test result from html from gradle 2", function()
		-- given
		local filename = vim.fn.getcwd() .. "/tests/fixtures/com.example.SimpleTest.html"

		-- when
		local actual = test_parser.parse_html_gradle_report(filename)

		-- then
		local expected = {
			["shouldPass"] = {
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

	it("should parse a parameterized test result from html with one single failing test", function()
		-- given
		local filename = vim.fn.getcwd() .. "/tests/fixtures/com.example.SimpleTest3.html"

		-- when
		local actual = test_parser.parse_html_gradle_report(filename)

		-- then
		local expected = {
			["shouldFail"] = {
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
		it("should return empty object when it has no parameterized test: " .. filepath, function()
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
