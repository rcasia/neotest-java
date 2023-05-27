DirFilter = {}

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
function DirFilter:filter_dir(name, rel_path, root)
	return rel_path:match("src/test/java") ~= nil
end

return DirFilter
