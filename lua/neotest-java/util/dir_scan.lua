--- @param dir neotest-java.Path
--- @return fun(): { path: neotest-java.Path, typ: "directory" | "file" } | nil
local iter_dir = function(dir)
	local handle = assert(vim.uv.fs_scandir(dir.to_string()))

	return function()
		local name, typ = vim.uv.fs_scandir_next(handle)
		if name ~= nil then
			return { path = dir.append(name), typ = typ }
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

	local seen = {}
	--- @return {path: neotest-java.Path, typ: "directory" | "file"}[]
	local find = function(_dir)
		seen[_dir.to_string()] = true
		return vim
			--
			.iter(iter_dir(_dir))
			:totable()
	end

	--- @type {path: neotest-java.Path, typ: "directory" | "file"}[]
	local result = find(dir)
	local all_seen = function()
		return vim.iter(result)
			:filter(function(result)
				return result.typ == "directory"
			end)
			:all(function(obj)
				local path_str = obj.path.to_string()
				return seen[path_str]
			end)
	end

	local hard_limit = 10000
	while not all_seen() do
		hard_limit = hard_limit - 1
		assert(hard_limit > 0, "Dir scan exceeded hard limit")

		local next_dir = vim.iter(result)
			:filter(function(r)
				return r.typ == "directory"
			end)
			:find(function(obj)
				assert(obj.typ == "directory")
				local path_str = obj.path.to_string()
				return not seen[path_str]
			end)

		result = vim.list_extend(result, find(next_dir.path))
	end
	return vim.iter(result)
		:map(function(obj)
			return obj.path
		end)
		:filter(contains(opts.search_patterns))
		:totable()
end

return scan
