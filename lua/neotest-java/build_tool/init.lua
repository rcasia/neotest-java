local maven = require("neotest-java.build_tool.maven")
local gradle = require("neotest-java.build_tool.gradle")

---@class neotest-java.BuildTool
---@field get_dependencies_classpath fun(): string
---@field get_output_dir fun(): string
---@field write_classpath fun(classpath_filepath: string) writes the classpath into a file
local BuildTool = {}

local build_tools = {}

--- will determine the build tool to use
---@return neotest-java.BuildTool
build_tools.get = function(project_type)
	if project_type == "gradle" then
		return gradle
	elseif project_type == "maven" then
		return maven
	end
	error("unknown project type: " .. project_type)
end

return build_tools
