local generate_spring_property_filepaths = require("neotest-java.util.spring_property_filepaths")
local Path = require("neotest-java.model.path")
local read_xml_tag = require("neotest-java.util.read_xml_tag")

local PROJECT_FILE = "pom.xml"

---@class neotest-java.MavenBuildTool : neotest-java.BuildTool
local maven = {}

function maven.get_build_dirname(base_dir)
	local pom_path = base_dir:append("pom.xml"):to_string()
	local build_dir = read_xml_tag(pom_path, "project.build.directory")
	return Path(build_dir or "target")
end

function maven.get_project_filename()
	return PROJECT_FILE
end

function maven.get_artifact_id(base_dir)
	local pom_path = base_dir:append("pom.xml"):to_string()
	return read_xml_tag(pom_path, "project.artifactId") or base_dir:name()
end

--- @param roots neotest-java.Path[]
function maven.get_spring_property_filepaths(roots)
	local base_dirs = vim
		.iter(roots)
		--- @param r neotest-java.Path
		:map(function(r)
			return {
				r:append("classes"),
				r:append("test-classes"),
			}
		end)
		:flatten()
		:totable()

	return generate_spring_property_filepaths(base_dirs)
end

---@type neotest-java.BuildTool
return maven
