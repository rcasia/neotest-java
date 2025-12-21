local async = require("nio").tests
local Project = require("neotest-java.types.project")
local Path = require("neotest-java.util.path")
local eq = assert.are.same

describe("project", function()
	local testscases = {
		{
			input = Path("./tests/fixtures/maven-demo"),
			expected = {
				{ name = "maven-demo", base_dir = Path("./tests/fixtures/maven-demo") },
			},
		},
		{
			input = Path("./tests/fixtures/gradle-groovy-demo"),
			expected = {
				{ name = "gradle-groovy-demo", base_dir = Path("./tests/fixtures/gradle-groovy-demo") },
			},
		},
	}
	for _, testcase in ipairs(testscases) do
		async.it("should get modules: " .. testcase.input.to_string(), function()
			local project = Project.from_root_dir(testcase.input)
			local results = {}
			for _, mod in ipairs(project:get_modules()) do
				results[#results + 1] = { name = mod.name, base_dir = mod.base_dir }
			end
			eq(testcase.expected, results)
		end)
	end
end)
