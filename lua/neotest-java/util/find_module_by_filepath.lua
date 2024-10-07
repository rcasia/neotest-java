local logger = require("neotest-java.logger")

---@param filepath string
---@param module_dirs string[]
---@return string | nil module_dir
local find_module_by_filepath = function(module_dirs, filepath)
	logger.debug("module_dirs", module_dirs)
	logger.debug("filepath", filepath)
	if not filepath or filepath == "" then
		return nil
	end

	-- Normalize paths to use forward slashes for Windows compatibility
	filepath = filepath:gsub("\\", "/")
	local normalized_module_dirs = vim.tbl_map(function(dir)
		return dir:gsub("\\", "/")
	end, module_dirs)

	local matches = {}

	for _, module_dir in ipairs(normalized_module_dirs) do
		-- Escape any special characters in module_dir for pattern matching
		local escaped_module_dir = module_dir:gsub("([^%w])", "%%%1")

		-- Build patterns to search for the module directory in the filepath
		local patterns = {
			"[%./]" .. escaped_module_dir .. "[%./]", -- Module in the middle
			"^" .. escaped_module_dir .. "[%./]", -- Module at the start
			"[%./]" .. escaped_module_dir .. "$", -- Module at the end
			"^" .. escaped_module_dir .. "$", -- Module is the entire path
		}

		for _, pattern in ipairs(patterns) do
			if filepath:find(pattern) then
				table.insert(matches, module_dir)
				break -- If we found a match for this module_dir, no need to check other patterns
			end
		end
	end

	-- Select the longest match from all the matches
	local longest_match = nil
	for _, match in ipairs(matches) do
		if not longest_match or #match > #longest_match then
			longest_match = match
		end
	end

	return longest_match
end

return find_module_by_filepath
