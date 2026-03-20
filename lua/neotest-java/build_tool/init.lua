local maven = require("neotest-java.build_tool.maven")
local gradle = require("neotest-java.build_tool.gradle")

---@class neotest-java.BuildTool
---@field get_build_dirname fun(base_dir: neotest-java.Path): neotest-java.Path
---@field get_project_filename fun(): string
---@field get_spring_property_filepaths fun(roots: neotest-java.Path[]): neotest-java.Path[]
---@field get_artifact_id fun(base_dir: neotest-java.Path): string

---@class neotest-java.BuildToolRegistry
local registry = {}

---@type table<string, neotest-java.BuildTool>
local build_tools = {
	maven = maven,
	gradle = gradle,
}

--- Get build tool by project type
---@param project_type string
---@return neotest-java.BuildTool
function registry.get(project_type)
	local tool = build_tools[project_type]
	if not tool then
		error("unknown project type: " .. project_type)
	end
	return tool
end

return registry
