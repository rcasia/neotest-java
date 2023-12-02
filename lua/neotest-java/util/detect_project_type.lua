--- @param buildtools table<neotest-java.BuildTool>
--- @param project_root_path string
--- @return neotest-java.BuildTool | nil
local function detect_project_type(buildtools, project_root_path)
	for _, buildtool in ipairs(buildtools) do
		for _, project_file in ipairs(buildtool.project_files) do
			if vim.fn.filereadable(project_root_path .. "/" .. project_file) == 1 then
				return buildtool
			end
		end
	end

	return nil
end

return detect_project_type
