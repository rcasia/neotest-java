local Path = require("neotest-java.model.path")

---@class neotest-java.BuildToolConfig
---@field project_filename string
---@field get_build_dirname fun(base_dir: neotest-java.Path, deps: table): string
---@field get_artifact_id fun(base_dir: neotest-java.Path, deps: table): string
---@field get_spring_subdirs fun(root: neotest-java.Path): neotest-java.Path[]

---@class neotest-java.BuildToolDeps
---@field read_xml_tag? fun(filepath: string, selector: string): string | nil
---@field generate_spring_property_filepaths fun(roots: neotest-java.Path[]): neotest-java.Path[]

--- Creates a build tool from a config and dependencies
---@param config neotest-java.BuildToolConfig
---@param deps neotest-java.BuildToolDeps
---@return neotest-java.BuildTool
local function create_build_tool(config, deps)
	---@type neotest-java.BuildTool
	return {
		get_build_dirname = function(base_dir)
			return Path(config.get_build_dirname(base_dir, deps))
		end,

		get_project_filename = function()
			return config.project_filename
		end,

		get_artifact_id = function(base_dir)
			return config.get_artifact_id(base_dir, deps)
		end,

		get_spring_property_filepaths = function(roots)
			local base_dirs = vim.iter(roots)
				:map(function(root)
					return root:append(config.get_build_dirname(root, deps))
				end)
				:map(config.get_spring_subdirs)
				:flatten()
				:totable()
			return deps.generate_spring_property_filepaths(base_dirs)
		end,
	}
end

return create_build_tool
