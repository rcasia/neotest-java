local generate_spring_property_filepaths = require("neotest-java.util.spring_property_filepaths")
local Path = require("neotest-java.util.path")

local PROJECT_FILENAME = "build.gradle"

---@class neotest-java.GradleBuildTool : neotest-java.BuildTool
local gradle = {}

gradle.get_build_dirname = function()
	return Path("bin")
end

function gradle.get_project_filename()
	return PROJECT_FILENAME
end

--- @param roots string[]
function gradle.get_spring_property_filepaths(roots)
	local base_dirs = vim
		.iter(roots)
		:map(Path)
		--- @param root neotest-java.Path
		:map(function(root)
			return {
				root.append("main"),
				root.append("test"),
			}
		end)
		:flatten()
		:totable()

	return generate_spring_property_filepaths(base_dirs)
end

---@type neotest-java.BuildTool
return gradle
