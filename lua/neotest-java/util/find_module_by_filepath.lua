local logger = require("neotest-java.logger")
local Path = require("neotest-java.util.path")

---@param filepath string
---@param module_dirs string[]
---@return string | nil module_dir
local find_module_by_filepath = function(module_dirs, filepath)
	if #module_dirs == 1 then
		return module_dirs[1]
	end
	--- @type neotest-java.Path[]
	local _module_dirs = vim.iter(module_dirs):map(Path):totable()
	--- @type neotest-java.Path
	local _filepath = Path(filepath)

	logger.debug("module_dirs", module_dirs)
	logger.debug("filepath", filepath)
	if not filepath or filepath == "" then
		return nil
	end

	--- @type neotest-java.Path[]
	local matches = {}

	for _, module_dir in ipairs(_module_dirs) do
		logger.debug(
			"Checking if module_dir '"
				.. module_dir.to_string()
				.. "' is contained in filepath '"
				.. _filepath.to_string()
				.. "'"
		)
		if _filepath.contains(module_dir.to_string()) then
			table.insert(matches, module_dir)
		end
	end

	logger.debug(
		"Found matches:",
		vim.tbl_map(function(path)
			return path.to_string()
		end, matches)
	)

	-- Select the longest match from all the matches
	--- @type neotest-java.Path | nil
	local longest_match = nil
	for _, path in ipairs(matches) do
		if not longest_match or #path.to_string() > #longest_match.to_string() then
			longest_match = path
		end
	end

	return longest_match and longest_match.to_string()
end

return find_module_by_filepath
