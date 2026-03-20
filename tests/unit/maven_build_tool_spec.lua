local Path = require("neotest-java.model.path")
local maven = require("neotest-java.build_tool.maven")

local assertions = require("tests.assertions")
local eq = assertions.eq
local it = require("nio").tests.it

describe("MavenBuildTool", function()
	describe("get_build_dirname", function()
		it("returns default target when no build directory is specified", function()
			local base_dir = Path("./tests/fixtures/maven-simple")
			local result = maven.get_build_dirname(base_dir)
			eq(Path("target"), result)
		end)

		it("returns custom build directory from pom.xml", function()
			local base_dir = Path("./tests/fixtures/maven-custom-build-dir")
			local result = maven.get_build_dirname(base_dir)
			eq(Path("custom-output/classes"), result)
		end)
	end)
end)
