--- @class neotest-java.Path
--- @field to_string fun(): string
--- @field parent fun(): neotest-java.Path
--- @field append fun(other: string): neotest-java.Path
--- @field name fun(): string
--- @field make_relative fun(other: neotest-java.Path): neotest-java.Path
--- @field contains fun(slug_term: string): boolean
--- @field slugs string[]

local PATH_METATABLE = {
	__tostring = function(path)
		return path.to_string()
	end,

	--- @param path1 neotest-java.Path
	--- @param path2 neotest-java.Path
	__eq = function(path1, path2)
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

	local first_char = raw_path:sub(1, 1)
	local is_absolute =
		--
		first_char == UNIX_SEPARATOR
		--
		or first_char == WINDOWS_SEPARATOR

	local slugs_fn = function()
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

		if is_absolute then
			table.insert(slugs, 1, "")
		end

		local has_relative_dot = raw_path:sub(1, 2) == "." .. UNIX_SEPARATOR
			or raw_path:sub(1, 2) == "." .. WINDOWS_SEPARATOR
		if has_relative_dot then
			table.insert(slugs, 1, ".")
		end

		return slugs
	end

	local to_string = function()
		local slugs = slugs_fn()
		if is_absolute and #slugs == 1 then
			return SEP
		end

		if #slugs == 0 then
			return "."
		end
		return vim.iter(slugs):join(SEP)
	end

	return setmetatable(
		--- @type neotest-java.Path
		{
			slugs = slugs_fn,
			name = function()
				local slugs = slugs_fn()
				return slugs[#slugs]
			end,
			append = function(other)
				return Path(raw_path .. SEP .. other, opts)
			end,
			parent = function()
				local slugs = slugs_fn()
				if is_absolute and #slugs == 2 then
					return Path(SEP, opts)
				end
				return Path(vim.iter(slugs):take(#slugs - 1):join(SEP), opts)
			end,
			make_relative = function(base_path)
				local this_string = to_string()
				local base_path_string = base_path.to_string()

				return Path(this_string:sub(#base_path_string + 2), opts)
			end,
			contains = function(slug_term)
				local this_slugs = slugs_fn()

				local other_slugs = Path(slug_term, opts).slugs()

				if #other_slugs == 0 or #other_slugs > #this_slugs then
					return false
				end

				for i = 1, #this_slugs - #other_slugs + 1 do
					local match = true
					for j = 1, #other_slugs do
						if this_slugs[i + j - 1] ~= other_slugs[j] then
							match = false
							break
						end
					end
					if match then
						return true
					end
				end

				return false
			end,
			to_string = to_string,
		},
		PATH_METATABLE
	)
end

return Path
