local async = require("nio").tests
local Project = require("neotest-java.types.project")

describe("project", function()
	local testscases = {
		{
			input = "./tests/fixtures/maven-demo",
			expected = {
				{ name = "maven-demo", base_dir = "./tests/fixtures/maven-demo" },
			},
		},
		{
			input = "./tests/fixtures/gradle-groovy-demo",
			expected = {
				{ name = "gradle-groovy-demo", base_dir = "./tests/fixtures/gradle-groovy-demo" },
			},
		},
	}
	for _, testcase in ipairs(testscases) do
		async.it("should get modules: " .. testcase.input, function()
			local project = Project.from_root_dir(testcase.input)
			local results = {}
			for _, mod in ipairs(project:get_modules()) do
				results[#results + 1] = { name = mod.name, base_dir = mod.base_dir }
			end
			assert.same(testcase.expected, results)
		end)
	end
end)
