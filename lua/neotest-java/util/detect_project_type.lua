--- @param project_root_path string
--- @return string "gradle" | "maven" | "unknown"
local function detect_project_type(project_root_path)
	local gradle_build_file = project_root_path .. "/build.gradle"
	local maven_build_file = project_root_path .. "/pom.xml"

	if vim.fn.filereadable(gradle_build_file) == 1 then
		return "gradle"
	elseif vim.fn.filereadable(maven_build_file) == 1 then
		return "maven"
	end

	return "unknown"
end

return detect_project_type
