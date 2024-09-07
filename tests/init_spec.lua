describe("NeotestJava plugin", function()
	local default_config = {
		ignore_wrapper = false,
		junit_jar = vim.fn.stdpath("data") .. "/neotest-java/junit-platform-console-standalone-1.10.1.jar",
		incremental_build = true,
	}

	it("should init default configuration", function()
		-- when
		require("neotest-java")

		-- then
		assert.are.same(default_config, require("neotest-java.context_holder").get_context().config)
	end)

	it("should init with empty configuration", function()
		-- when
		require("neotest-java")({})

		-- then
		assert.are.same(default_config, require("neotest-java.context_holder").get_context().config)
	end)
end)
