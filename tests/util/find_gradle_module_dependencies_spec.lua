local async = require("nio").tests
local find_gradle_module_dependencies = require("neotest-java.util.find_gradle_module_dependencies")

describe("find_gradle_module_dependencies function", function()
	async.it("should find module dependencies", function()
		local filepath = "tests/fixtures/build-example.gradle"

		local result = find_gradle_module_dependencies(filepath)

		assert.same({
			["sample-api"] = { "sample-common" },
			["sample-admin"] = { "sample-common" },
		}, result)
	end)
end)
