local Path = require("neotest-java.util.path")

--- @type neotest-java.BuildTool
return {
	get_build_dirname = function()
		return Path("target")
	end,
	get_module_dependencies = function()
		return {}
	end,
	get_project_filename = function()
		return "pom.xml"
	end,
	get_spring_property_filepaths = function()
		return {}
	end,

	get_classpaths = function()
		return {
			"/user/home/target/classes",
			"/user/home/target/test-classes",
		}
	end,
}
