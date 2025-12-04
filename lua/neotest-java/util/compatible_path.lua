---@param path string
---@return string compatible_path
local function compatible_path(path)
	-- check if the system is windows
	local has_win = vim.fn.has("win64") == 1 or vim.fn.has("win32") == 1
	-- set path separator based on the system
	local sep = has_win and "\\" or "/"

	-- preserve relative path prefix if present
	local relative_prefix = ""
	if path:sub(1, 2) == "./" or path:sub(1, 2) == ".\\" then
		relative_prefix = "." .. sep
	end

	-- replace separators with the system's separator
	path = path:gsub("%./", sep):gsub("%.\\", sep):gsub("/", sep):gsub("\\", sep)

	-- normalize the path and remove duplicate separators
	return (relative_prefix .. path):gsub(sep .. "+", sep)
end

return compatible_path
