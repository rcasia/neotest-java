local Path = require("neotest-java.model.path")
local spring = require("neotest-java.util.spring_property_filepaths")

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
	get_spring_property_filepaths = function(roots)
		-- just to check that the function does not error in tests
		spring(roots)

		return {
			Path("src/main/resources/application.properties"),
		}
	end,

	get_classpaths = function()
		return {
			"/user/home/target/classes",
			"/user/home/target/test-classes",
		}
	end,
}
