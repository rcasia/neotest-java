local Path = require("neotest-java.model.path")

---@type neotest-java.BuildToolConfig
local gradle_config = {
	project_filename = "build.gradle",

	get_build_dirname = function(_base_dir, _deps)
		return Path("bin")
	end,

	get_artifact_id = function(base_dir, _deps)
		return base_dir:name()
	end,

	get_spring_subdirs = function(root)
		return {
			root:append("main"),
			root:append("test"),
		}
	end,
}

return gradle_config
