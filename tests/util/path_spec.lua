local Path = require("neotest-java.util.path")

local eq = assert.are.same

describe("Path", function()
	local cases = {
		{
			input_path = "/////some//////test///////path",
			expected = "/some/test/path",
			separator = "/",
		},
		{
			input_path = "\\some\\test\\path",
			expected = "/some/test/path",
			separator = "/",
		},
		{
			input_path = "/some/test/path",
			expected = "/some/test/path",
			separator = "/",
		},
		{
			input_path = "/some/test/path",
			expected = "\\some\\test\\path",
			separator = "\\",
		},
		{
			input_path = "\\some\\test\\path",
			expected = "\\some\\test\\path",
			separator = "\\",
		},
		{
			input_path = "\\\\\\some\\\\\\\\test\\\\\\\\path",
			expected = "\\some\\test\\path",
			separator = "\\",
		},
	}
	for _, case in ipairs(cases) do
		it("creates path: " .. case.input_path, function()
			local path = Path(case.input_path, {
				separator = function()
					return case.separator
				end,
			})
			eq(case.expected, path.to_string())
		end)
	end

	local cases_parent = {
		{
			description = "[unix] base case for parent",
			input_path = "/some/test/path",
			expected_parent = "/some/test",
			separator = "/",
		},
		{
			description = "[unix] parent is root",
			input_path = "/some",
			expected_parent = "/",
			separator = "/",
		},
		{
			description = "[win] parent is root",
			input_path = "\\some",
			expected_parent = "\\",
			separator = "\\",
		},
	}
	for _, case in ipairs(cases_parent) do
		it("gets parent path: " .. case.description, function()
			local path = Path(case.input_path, {
				separator = function()
					return case.separator
				end,
			})
			eq(case.expected_parent, path.parent().to_string())
		end)
	end

	local cases_append = {
		{
			input_path = "/some",
			append_path = "test",
			expected = "/some/test",
			separator = "/",
		},
		{
			input_path = "\\some",
			append_path = "test",
			expected = "\\some\\test",
			separator = "\\",
		},
	}
	for _, case in ipairs(cases_append) do
		it("appends path: " .. case.input_path .. " + " .. case.append_path, function()
			local path = Path(case.input_path, {
				separator = function()
					return case.separator
				end,
			})
			eq(case.expected, path.append(case.append_path).to_string())
		end)
	end
end)
