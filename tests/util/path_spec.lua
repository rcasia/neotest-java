local Path = require("neotest-java.util.path")

local eq = assert.are.same

describe("Path", function()
	local cases = {
		{
			input_path = "/some/test/path",
			expected = "/some/test/path",
			windows = false,
		},
		{
			input_path = "\\some\\test\\path",
			expected = "\\some\\test\\path",
			windows = true,
		},
	}
	for _, case in ipairs(cases) do
		it("creates path: " .. case.input_path, function()
			local path = Path(case.input_path, { windows = case.windows })
			eq(case.expected, path.to_string())
		end)
	end

	local cases_parent = {
		{
			input_path = "/some/test/path",
			expected_parent = "/some/test",
			windows = false,
		},
		{
			input_path = "/some",
			expected_parent = "/",
			windows = false,
		},
		{
			input_path = "\\some",
			expected_parent = "\\",
			windows = true,
		},
	}
	for _, case in ipairs(cases_parent) do
		it("gets parent path: " .. case.input_path, function()
			local path = Path(case.input_path, { windows = case.windows })
			eq(case.expected_parent, path.parent().to_string())
		end)
	end

	local cases_append = {
		{
			input_path = "/some",
			append_path = "test",
			expected = "/some/test",
			windows = false,
		},
		{
			input_path = "\\some",
			append_path = "test",
			expected = "\\some\\test",
			windows = true,
		},
	}
	for _, case in ipairs(cases_append) do
		it("appends path: " .. case.input_path .. " + " .. case.append_path, function()
			local path = Path(case.input_path, { windows = case.windows })
			eq(case.expected, path.append(case.append_path).to_string())
		end)
	end
end)
