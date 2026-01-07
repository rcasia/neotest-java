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

	it("does not throw when adapter is initialized outside of a java project", function()
		--- @type neotest-java.Adapter
		local adapter = require("neotest-java")({}, {
			root_finder = {
				find_root = function()
					return nil
				end,
			},
		})
		eq(nil, adapter.root("some_dir"))
	end)
end)
