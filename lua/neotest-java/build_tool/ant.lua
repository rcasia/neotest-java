local compatible_path = require("neotest-java.util.compatible_path")

local PROJECT_FILE = "build.xml"

---@class neotest-java.AntBuildTool : neotest-java.BuildTool
local ant = {}

ant.get_output_dir = function(root)
	root = root and root or "."
	return compatible_path(root .. "/build/classes")
end

function ant.get_project_filename()
	return PROJECT_FILE
end

---@type neotest-java.BuildTool
return ant
