local compatible_path = require("neotest-java.util.compatible_path")
local generate_spring_property_filepaths = require("neotest-java.util.spring_property_filepaths")
local Path = require("neotest-java.util.path")

local PROJECT_FILENAME = "build.gradle"

---@class neotest-java.GradleBuildTool : neotest-java.BuildTool
local gradle = {}

gradle.get_output_dir = function(root)
	root = root and root or "."
	return compatible_path(root .. "/bin")
end

gradle.get_build_dirname = function()
	return Path("bin")
end

function gradle.get_project_filename()
	return PROJECT_FILENAME
end

--- @param roots string[]
function gradle.get_spring_property_filepaths(roots)
	local base_dirs = vim.iter(roots)
		:map(function(root)
			return {
				gradle.get_output_dir(root) .. "/main",
				gradle.get_output_dir(root) .. "/test",
			}
		end)
		:flatten()
		:totable()

	return generate_spring_property_filepaths(base_dirs)
end

---@type neotest-java.BuildTool
return gradle
