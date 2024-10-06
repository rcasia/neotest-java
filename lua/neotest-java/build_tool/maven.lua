local compatible_path = require("neotest-java.util.compatible_path")

local PROJECT_FILE = "pom.xml"

---@class neotest-java.MavenBuildTool : neotest-java.BuildTool
local maven = {}

maven.get_output_dir = function(root)
	root = root and root or "."
	-- TODO: read from pom.xml <build><directory>
	return compatible_path(root .. "/target/classes")
end

function maven.get_project_filename()
	return PROJECT_FILE
end

---@type neotest-java.BuildTool
return maven
