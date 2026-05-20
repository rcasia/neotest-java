local Path = require("neotest-java.model.path")
local create_build_tool = require("neotest-java.build_tool.build_tool")
local read_xml_tag = require("neotest-java.util.read_xml_tag")
local generate_spring_property_filepaths = require("neotest-java.util.spring_property_filepaths")

local assertions = require("tests.assertions")
local eq = assertions.eq
local async = require("tests.async_helpers").async

describe("MavenBuildTool", function()
	local maven = create_build_tool({
		project_filename = "pom.xml",
		get_build_dirname = function(base_dir, deps)
			local pom_path = base_dir:append("pom.xml"):to_string()
			local build_dir = deps.read_xml_tag(pom_path, "project.build.directory")
			return Path(build_dir or "target")
		end,
		get_artifact_id = function(base_dir, deps)
			local pom_path = base_dir:append("pom.xml"):to_string()
			return deps.read_xml_tag(pom_path, "project.artifactId") or base_dir:name()
		end,
		get_spring_subdirs = function(root)
			return { root:append("classes"), root:append("test-classes") }
		end,
	}, {
		read_xml_tag = read_xml_tag,
		generate_spring_property_filepaths = generate_spring_property_filepaths,
	})

	describe("get_build_dirname", function()
		it(
			"returns default target when no build directory is specified",
			async(function()
				local base_dir = Path("./tests/fixtures/maven-simple")
				local result = maven.get_build_dirname(base_dir)
				eq(Path("target"), result)
			end)
		)

		it(
			"returns custom build directory from pom.xml",
			async(function()
				local base_dir = Path("./tests/fixtures/maven-custom-build-dir")
				local result = maven.get_build_dirname(base_dir)
				eq(Path("custom-output/classes"), result)
			end)
		)
	end)
end)
