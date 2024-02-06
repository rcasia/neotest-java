DirFilter = {
	-- List of directories to exclude from search
	excluded_directories = {
		"target",
		"build",
		"out",
		"bin",
		"resources",
		"main",
	},
}

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
function DirFilter.filter_dir(name, rel_path, root)
	for _, v in ipairs(DirFilter.excluded_directories) do
		if string.find(rel_path, "test") then
			return true
		end

		if string.find(rel_path, v) then
			return false
		end
	end

	return true
end

return DirFilter
