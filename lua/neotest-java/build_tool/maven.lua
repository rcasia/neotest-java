local generate_spring_property_filepaths = require("neotest-java.util.spring_property_filepaths")
local Path = require("neotest-java.util.path")

local PROJECT_FILE = "pom.xml"

---@class neotest-java.MavenBuildTool : neotest-java.BuildTool
local maven = {}

maven.get_output_dir = function(root)
	root = root and root or "."
	-- TODO: read from pom.xml <build><directory>
	return Path(root).append("target/classes")
end

function maven.get_project_filename()
	return PROJECT_FILE
end

--- @param roots string[]
function maven.get_spring_property_filepaths(roots)
	local base_dirs = vim.iter(roots)
		:map(function(root)
			return {
				maven.get_output_dir(root).append("classes").to_string(),
				maven.get_output_dir(root).append("/test-classes").to_string(),
			}
		end)
		:flatten()
		:totable()

	return generate_spring_property_filepaths(base_dirs)
end

---@type neotest-java.BuildTool
return maven
