--- @class neotest-java.Path
--- @field to_string fun(): string
--- @field parent fun(): neotest-java.Path
--- @field append fun(other: string): neotest-java.Path
--- @field name fun(): string

local PATH_METATABLE = {

	--- @param path1 neotest-java.Path
	--- @param path2 neotest-java.Path
	__eq = function(path1, path2)
		print("Comparing paths:", path1:to_string(), path2:to_string())
		-- check if both are actually tables to avoid errors
		if type(path1) ~= "table" or type(path2) ~= "table" then
			return false
		end
		return path1.to_string() == path2.to_string()
	end,
}

local UNIX_SEPARATOR = "/"
local WINDOWS_SEPARATOR = "\\"

local is_not_empty = function(s)
	return s ~= nil and s ~= ""
end

local is_not_dot = function(s)
	return s ~= "."
end

local remove_separator = function(s)
	local clean = string.gsub(s, UNIX_SEPARATOR, ""):gsub(WINDOWS_SEPARATOR, "")
	return clean
end

local separator = function()
	if vim.fn.has("win64") == 1 or vim.fn.has("win32") == 1 then
		return WINDOWS_SEPARATOR
	end
	return UNIX_SEPARATOR
end

--- @return neotest-java.Path
--- @param raw_path string
--- @param opts? { separator?: fun(): string }
local function Path(raw_path, opts)
	local SEP = (opts and opts.separator) and opts.separator() or separator()

	local slugs = vim
		--
		.iter(vim.split(raw_path, WINDOWS_SEPARATOR))
		:map(function(s)
			return vim.split(s, UNIX_SEPARATOR)
		end)
		:flatten()
		:filter(is_not_empty)
		:filter(is_not_dot)
		:map(remove_separator)
		:totable()
	local first_char = raw_path:sub(1, 1)
	local is_absolute =
		--
		first_char == UNIX_SEPARATOR
		--
		or first_char == WINDOWS_SEPARATOR

	if is_absolute then
		table.insert(slugs, 1, "")
	end

	local has_relative_dot = raw_path:sub(1, 2) == "." .. UNIX_SEPARATOR
		or raw_path:sub(1, 2) == "." .. WINDOWS_SEPARATOR
	if has_relative_dot then
		table.insert(slugs, 1, ".")
	end

	return setmetatable({
		name = function()
			return slugs[#slugs]
		end,
		append = function(other)
			return Path(raw_path .. SEP .. other, opts)
		end,
		parent = function()
			if is_absolute and #slugs == 2 then
				return Path(SEP, opts)
			end
			return Path(vim.iter(slugs):take(#slugs - 1):join(SEP), opts)
		end,
		to_string = function()
			if is_absolute and #slugs == 1 then
				return SEP
			end
			return vim.iter(slugs):join(SEP)
		end,
	}, PATH_METATABLE)
end

return Path
