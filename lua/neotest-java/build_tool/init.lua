local create_build_tool = require("neotest-java.build_tool.build_tool")
local maven_config = require("neotest-java.build_tool.maven")
local gradle_config = require("neotest-java.build_tool.gradle")
local read_xml_tag = require("neotest-java.util.read_xml_tag")
local generate_spring_property_filepaths = require("neotest-java.util.spring_property_filepaths")

---@class neotest-java.BuildTool
---@field get_build_dirname fun(base_dir: neotest-java.Path): neotest-java.Path
---@field get_project_filename fun(): string
---@field get_spring_property_filepaths fun(roots: neotest-java.Path[]): neotest-java.Path[]
---@field get_artifact_id fun(base_dir: neotest-java.Path): string

---@class neotest-java.BuildToolRegistry
local registry = {}

---@type neotest-java.BuildToolDeps
local deps = {
	read_xml_tag = read_xml_tag,
	generate_spring_property_filepaths = generate_spring_property_filepaths,
}

---@type table<string, neotest-java.BuildTool>
local build_tools = {
	maven = create_build_tool(maven_config, deps),
	gradle = create_build_tool(gradle_config, deps),
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
