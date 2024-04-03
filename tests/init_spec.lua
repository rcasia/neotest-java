describe("NeotestJava plugin", function()
	local default_config = {
		ignore_wrapper = false,
		junit_jar = vim.fn.stdpath("data") .. "/neotest-java/junit-platform-console-standalone-1.10.1.jar",
	}

	it("should init default configuration", function()
		-- when
		local plugin = require("neotest-java")

		-- then
		assert.are.same(default_config, plugin.config)
	end)

	it("should init with empty configuration", function()
		-- when
		local plugin = require("neotest-java")({})

		-- then
		assert.are.same(default_config, plugin.config)
	end)
end)
