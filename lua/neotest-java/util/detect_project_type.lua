local compatible_path = require("neotest-java.util.compatible_path")
local maven = require("neotest-java.build_tool.maven")
local gradle = require("neotest-java.build_tool.gradle")
local ant = require("neotest-java.build_tool.ant")
--- @param project_root_path string
--- @return string "gradle" | "maven" | "ant" | "unknown"
local function detect_project_type(project_root_path)
	local gradle_kotlin_build_file =
		compatible_path(project_root_path .. "/" .. gradle.get_project_filename() .. ".kts")
	local gradle_groovy_build_file = compatible_path(project_root_path .. "/" .. gradle.get_project_filename())
	local maven_build_file = compatible_path(project_root_path .. "/" .. maven.get_project_filename())
	local ant_build_file = compatible_path(project_root_path .. "/" .. ant.get_project_filename())

	if vim.fn.filereadable(gradle_groovy_build_file) == 1 or vim.fn.filereadable(gradle_kotlin_build_file) == 1 then
		return "gradle"
	elseif vim.fn.filereadable(maven_build_file) == 1 then
		return "maven"
	elseif vim.fn.filereadable(ant_build_file) == 1 then
		return "ant"
	end

	return "unknown"
end

return detect_project_type
