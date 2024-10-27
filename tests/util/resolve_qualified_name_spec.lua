local a = require("nio").tests
local resolve_qualified_name = require("neotest-java.util.resolve_qualified_name")

describe("resolve_qualified_name", function()
	local tmp_files

	before_each(function()
		tmp_files = {}
	end)

	after_each(function()
		-- clear temporary files
		for _, file in ipairs(tmp_files) do
			os.remove(file)
		end
	end)

	---@param content string
	---@return string filename
	local function create_tmp_file(content)
		local tmp_file = os.tmpname()
		table.insert(tmp_files, tmp_file)
		local file = assert(io.open(tmp_file, "w"))
		file:write(content)
		file:close()
		return tmp_file
	end

	local testcases = {
		{
			input = [[
    package com.example;

    public class ExampleTest {}

    ]],
			expected = "com.example.ExampleTest",
		},
	}

	for _, case in ipairs(testcases) do
		a.it("should resolve the qualified name of a file", function()
			local result = resolve_qualified_name(create_tmp_file(case.input))

			assert.are.same(case.expected, result)
		end)
	end
end)
