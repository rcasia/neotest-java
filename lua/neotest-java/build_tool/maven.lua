local Path = require("neotest-java.model.path")

---@type neotest-java.BuildToolConfig
local maven_config = {
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
		return {
			root:append("classes"),
			root:append("test-classes"),
		}
	end,
}

return maven_config
