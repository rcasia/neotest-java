--- @class neotest-java.Path
--- @field to_string fun(): string
--- @field parent fun(): neotest-java.Path
--- @field append fun(other: string): neotest-java.Path

local is_not_empty = function(s)
	return s ~= nil and s ~= ""
end

local remove_separator = function(separator)
	return function(s)
		local clean = string.gsub(s, separator, "")
		return clean
	end
end

--- @return neotest-java.Path
--- @param raw_path string
--- @param opts? { windows?: boolean }
local function Path(raw_path, opts)
	local has_win = opts and opts.windows or vim.fn.has("win64") == 1 or vim.fn.has("win32") == 1
	local SEP = has_win and "\\" or "/"

	local slugs = vim
		--
		.iter(vim.split(raw_path, SEP))
		:filter(is_not_empty)
		:map(remove_separator(SEP))
		:totable()
	local is_absolute = raw_path:sub(1, 1) == SEP

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
