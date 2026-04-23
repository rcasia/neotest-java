local create_build_tool = require("neotest-java.build_tool.build_tool")
local Path = require("neotest-java.model.path")
local read_xml_tag = require("neotest-java.util.read_xml_tag")
local generate_spring_property_filepaths = require("neotest-java.util.spring_property_filepaths")

---@class neotest-java.BuildTool
---@field get_build_dirname fun(base_dir: neotest-java.Path): neotest-java.Path
---@field get_project_filename fun(): string
---@field get_spring_property_filepaths fun(roots: neotest-java.Path[]): neotest-java.Path[]
---@field get_artifact_id fun(base_dir: neotest-java.Path): string

---@type neotest-java.BuildToolDeps
local deps = {
	read_xml_tag = read_xml_tag,
	generate_spring_property_filepaths = generate_spring_property_filepaths,
}

---@type table<string, neotest-java.BuildTool>
local build_tools = {
	maven = create_build_tool({
		project_filename = "pom.xml",
		get_build_dirname = function(base_dir, d)
			local pom_path = base_dir:append("pom.xml"):to_string()
			local build_dir = d.read_xml_tag(pom_path, "project.build.directory")
			return build_dir or "target"
		end,
		get_artifact_id = function(base_dir, d)
			local pom_path = base_dir:append("pom.xml"):to_string()
			return d.read_xml_tag(pom_path, "project.artifactId") or base_dir:name()
		end,
		get_spring_subdirs = function(root)
			return { root:append("classes"), root:append("test-classes") }
		end,
	}, deps),

	gradle = create_build_tool({
		project_filename = "%.gradle",
		get_build_dirname = function(_base_dir, _d)
			return Path("bin")
		end,
		get_artifact_id = function(base_dir, _d)
			return base_dir:name()
		end,
		get_spring_subdirs = function(root)
			return { root:append("main"), root:append("test") }
		end,
	}, deps),
}

--- Get build tool by project type
---@param project_type string
---@return neotest-java.BuildTool
local function get(project_type)
	local tool = build_tools[project_type]
	if not tool then
		error("unknown project type: " .. project_type)
	end
	return tool
end

return { get = get }
