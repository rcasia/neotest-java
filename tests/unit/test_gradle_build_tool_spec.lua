local Path = require("neotest-java.model.path")
local build_tools = require("neotest-java.build_tool")

local assertions = require("tests.assertions")
local eq = assertions.eq
local async = require("tests.async_helpers").async

describe("GradleBuildTool", function()
	local gradle = build_tools.get("gradle")

	describe("get_build_dirname", function()
		it(
			"returns bin",
			async(function()
				local base_dir = Path("not/used")
				local result = gradle.get_build_dirname(base_dir)
				eq(Path("bin"), result)
			end)
		)
	end)
end)
