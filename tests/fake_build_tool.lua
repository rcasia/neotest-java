return {
	get_output_dir = function()
		return "/user/home/target"
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
