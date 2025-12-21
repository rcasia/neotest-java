local Path = require("neotest-java.util.path")

local eq = assert.are.same

describe("Path", function()
	it("two paths are equal if their string representations are equal", function()
		local raw_path = "/some/test/path"
		assert(Path(raw_path) == Path(raw_path), "should be equal when same string")
	end)

	it("can determine whether it contains a slug or not", function()
		local path = Path("/home/user/repo")
		eq(true, path.contains("home"), "should return true")
		eq(false, path.contains("hom"), "should return false")
	end)

	local relative_cases = {
		{
			base_path = "/some/test",
			full_path = "/some/test/path/to/file",
			expected_relative = "path/to/file",
		},
		{
			base_path = "/some/test/",
			full_path = "/some/test/path/to/file",
			expected_relative = "path/to/file",
		},
		{
			base_path = "/some/test",
			full_path = "/some/test/",
			expected_relative = "",
		},
		{
			base_path = "C:\\absolute_path\\",
			full_path = "C:\\absolute_path\\src\\main\\java\\neotest\\NeotestTest.java",
			expected_relative = "src\\main\\java\\neotest\\NeotestTest.java",
		},
	}
	for _, case in ipairs(relative_cases) do
		it("can make a relative path from '" .. case.full_path .. "' to '" .. case.base_path .. "'", function()
			local base_path = Path(case.base_path)
			local full_path = Path(case.full_path)

			local relative_path = full_path.make_relative(base_path)

			eq(Path(case.expected_relative).to_string(), relative_path.to_string())
		end)
	end

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
			input_path = "./some/test/./path",
			expected = "./some/test/path",
			separator = "/",
		},
		{
			input_path = "/some/test/./path",
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
