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

--- @return neotest-java.Path
--- @param raw_path string
--- @param opts? { windows?: boolean }
local function Path(raw_path, opts)
	local has_win = opts and opts.windows or vim.fn.has("win64") == 1 or vim.fn.has("win32") == 1
	local SEP = has_win and WINDOWS_SEPARATOR or UNIX_SEPARATOR

	local slugs = vim
		--
		.iter(vim.split(raw_path, WINDOWS_SEPARATOR, { trimempty = true }))
		:map(function(s)
			return vim.split(s, UNIX_SEPARATOR, { trimempty = true })
		end)
		:flatten()
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
