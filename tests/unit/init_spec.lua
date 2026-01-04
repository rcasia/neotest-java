local default_config = require("neotest-java.default_config")
local eq = assert.are.same

describe("NeotestJava plugin", function()
	it("should init default configuration", function()
		do
			local adapter = require("neotest-java")
			eq(default_config, adapter.config)
		end

		do
			local adapter = require("neotest-java")({})
			eq(default_config, adapter.config)
		end
	end)
end)
