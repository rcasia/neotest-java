local Path = require("neotest-java.model.path")

describe("NeotestJava plugin", function()
	local default_config = {
		default_version = "1.10.1",
		junit_jar = Path(vim.fn.stdpath("data") .. "/neotest-java/junit-platform-console-standalone-1.10.1.jar"),
		incremental_build = true,
	}

	it("should init default configuration", function()
		-- when
		require("neotest-java")

		-- then
		local actual_config = require("neotest-java.context_holder").get_context().config
		assert.are.same(
			{ unpack(default_config), junit_jar = default_config.junit_jar:to_string() },
			{ unpack(actual_config), junit_jar = actual_config.junit_jar:to_string() }
		)
	end)

	it("should init with empty configuration", function()
		-- when
		require("neotest-java")({})

		-- then
		local actual_config = require("neotest-java.context_holder").get_context().config
		assert.are.same(
			{ unpack(default_config), junit_jar = default_config.junit_jar:to_string() },
			{ unpack(actual_config), junit_jar = actual_config.junit_jar:to_string() }
		)
	end)
end)
