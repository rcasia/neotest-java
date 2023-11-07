describe("NeotestJava plugin", function()
	it("should init default configuration", function()
		-- given
		local expected_config = {
			ignore_wrapper = false,
		}

		-- when
		local plugin = require("neotest-java")

		-- then
		assert.are.same(expected_config, plugin.config)
	end)

	it("should init with empty configuration", function()
		-- given
		local expected_config = {
			ignore_wrapper = false,
		}

		-- when
		local plugin = require("neotest-java")({})

		-- then
		assert.are.same(expected_config, plugin.config)
	end)
end)
