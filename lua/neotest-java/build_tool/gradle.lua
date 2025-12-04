local generate_spring_property_filepaths = require("neotest-java.util.spring_property_filepaths")
local Path = require("neotest-java.util.path")

local PROJECT_FILENAME = "build.gradle"

---@class neotest-java.GradleBuildTool : neotest-java.BuildTool
local gradle = {}

gradle.get_output_dir = function(root)
	root = root and root or "."
	return Path(root).append("bin")
end

function gradle.get_project_filename()
	return PROJECT_FILENAME
end

--- @param roots string[]
function gradle.get_spring_property_filepaths(roots)
	local base_dirs = vim.iter(roots)
		:map(function(root)
			return {
				gradle.get_output_dir(root).append("main").to_string(),
				gradle.get_output_dir(root).append("/test").to_string(),
			}
		end)
		:flatten()
		:totable()

	return generate_spring_property_filepaths(base_dirs)
end

---@type neotest-java.BuildTool
return gradle
