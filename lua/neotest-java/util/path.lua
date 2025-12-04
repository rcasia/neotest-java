--- @class neotest-java.Path
--- @field to_string fun(): string
--- @field parent fun(): neotest-java.Path
--- @field append fun(other: string): neotest-java.Path

local UNIX_SEPARATOR = "/"
local WINDOWS_SEPARATOR = "\\"

local is_not_empty = function(s)
	return s ~= nil and s ~= ""
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

	return {
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
	}
end

return Path
