--- @class neotest-java.DirScanResultItem
--- @field path neotest-java.Path
--- @field typ "directory" | "file"

--- @param dir neotest-java.Path
--- @return fun(): neotest-java.DirScanResultItem | nil
local iter_dir = function(dir)
	local handle = assert(vim.uv.fs_scandir(dir:to_string()))

	return function()
		local name, typ = vim.uv.fs_scandir_next(handle)
		if name ~= nil then
			return { path = dir:append(name), typ = typ }
		end
	end
end

--- @param patterns string[]
--- @return fun(path: neotest-java.Path): boolean
local contains = function(patterns)
	local has_patterns = type(patterns) == "table" and #patterns > 0

	--- @param path neotest-java.Path
	return function(path)
		if not has_patterns then
			return true
		end

		return vim.iter(patterns):any(function(pattern)
			return path:to_string():match(pattern)
		end)
	end
end

---@class neotest-java.DirScanDependencies
---@field iter_dir fun(dir: neotest-java.Path): fun(): neotest-java.DirScanResultItem | nil

---@param dir neotest-java.Path
---@param opts? { search_patterns: string[] }
---@param dependencies? neotest-java.DirScanDependencies
local function scan(dir, opts, dependencies)
	opts = opts or {}
	dependencies = dependencies or {}
	iter_dir = dependencies.iter_dir or iter_dir

	local stack = { dir }
	local result = {}
	local filter = contains(opts.search_patterns)

	while #stack > 0 do
		local current_dir = table.remove(stack)
		for entry in iter_dir(current_dir) do
			if entry.typ == "directory" then
				table.insert(stack, entry.path)
			end
			if filter(entry.path) then
				table.insert(result, entry.path)
			end
		end
	end

	return result
end

return scan
