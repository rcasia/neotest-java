--- @param dir neotest-java.Path
--- @return fun(): neotest-java.Path | nil
local iter_dir = function(dir)
	local handle = assert(vim.uv.fs_scandir(dir.to_string()))

	return function()
		local name = vim.uv.fs_scandir_next(handle)
		if name ~= nil then
			return dir.append(name)
		end
	end
end

--- @param patterns string[]
--- @return fun(path: neotest-java.Path): boolean
local contains = function(patterns)
	local has_patterns = type(patterns) == "table" and #patterns

	--- @param path neotest-java.Path
	return function(path)
		if not has_patterns then
			return true
		end

		return vim.iter(patterns):any(function(pattern)
			return path.to_string():match(pattern)
		end)
	end
end

---@class neotest-java.DirScanDependencies
---@field iter_dir fun(dir: neotest-java.Path): fun(): string | nil

---@param dir neotest-java.Path
---@param opts? { search_patterns: string[] }
---@param dependencies? neotest-java.DirScanDependencies
local function scan(dir, opts, dependencies)
	opts = opts or {}
	dependencies = dependencies or {}
	iter_dir = dependencies.iter_dir or iter_dir

	return vim
		--
		.iter(iter_dir(dir))
		:filter(contains(opts.search_patterns))
		:totable()
end

return scan
