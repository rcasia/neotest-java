DirFilter = {}

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
function DirFilter:filter_dir(name, rel_path, root)
	local excluded = {
		"target",
		"build",
		"out",
		"bin",
		"resources",
		"main",
	}

	for _, v in ipairs(excluded) do
		if name == v then
			return false
		end
	end

	return true
end

return DirFilter
