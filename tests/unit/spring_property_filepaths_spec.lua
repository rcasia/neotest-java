local generate_spring_property_filepaths = require("neotest-java.util.spring_property_filepaths")
local Path = require("neotest-java.model.path")
local eq = assert.are.same

describe("Spring Property Filepaths", function()
	it("returs empty if base_dirs parameter is empty", function()
		eq({}, generate_spring_property_filepaths({}))
	end)

	it("returns generated paths", function()
		local base_dirs = {
			Path("src/main/resources"),
		}
		eq({
			Path("optional:file:src/main/resources/application.yml"),
			Path("optional:file:src/main/resources/application.yaml"),
			Path("optional:file:src/main/resources/application.properties"),
			Path("optional:file:src/main/resources/application-test.yml"),
			Path("optional:file:src/main/resources/application-test.yaml"),
			Path("optional:file:src/main/resources/application-test.properties"),
		}, generate_spring_property_filepaths(base_dirs))
	end)
end)
