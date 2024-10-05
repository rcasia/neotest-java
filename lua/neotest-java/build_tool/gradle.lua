local compatible_path = require("neotest-java.util.compatible_path")
local JAVA_FILE_PATTERN = ".+%.java$"
local PROJECT_FILENAME = "build.gradle"

---@class neotest-java.GradleBuildTool : neotest-java.BuildTool
local gradle = {}

gradle.get_output_dir = function(root)
	root = root and root or "."
	return compatible_path(root .. "/bin")
end

function gradle.get_project_filename()
	return PROJECT_FILENAME
end
---@type neotest-java.BuildTool
return gradle
