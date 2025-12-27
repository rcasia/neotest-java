local generate_spring_property_filepaths = require("neotest-java.util.spring_property_filepaths")
local eq = assert.are.same

describe("Spring Property Filepaths", function()
	it("returs empty if base_dirs parameter is empty", function()
		eq({}, generate_spring_property_filepaths({}))
	end)
end)
