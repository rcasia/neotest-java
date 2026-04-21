--- @class neotest-java.PathOpts
--- @field separator? fun(): string Function returning the path separator to use.

--- @class neotest-java.Path
--- @field raw_path string The original path string.
--- @field is_absolute boolean Whether the path is absolute.
--- @field separator string The path separator used (e.g., "/" or "\").
--- @field opts neotest-java.PathOpts Additional options for path handling.
--- @overload fun(raw_path: string, opts?: neotest-java.PathOpts): neotest-java.Path
local Path = {}

local PATH_METATABLE = {

	__index = Path,
	__tostring = function(path)
		return path:to_string()
	end,

	--- @param path1 neotest-java.Path
	--- @param path2 neotest-java.Path
	__eq = function(path1, path2)
		-- check if both are actually tables to avoid errors
		if type(path1) ~= "table" or type(path2) ~= "table" then
			return false
		end
		return path1:to_string() == path2:to_string()
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
local SEPARATOR = separator()

--- Create a new Path instance.
--- @param raw_path string
--- @param opts? neotest-java.PathOpts
--- @return neotest-java.Path
function Path.new(raw_path, opts)
	local SEP = (opts and opts.separator) and opts.separator() or SEPARATOR

	local first_char = raw_path:sub(1, 1)
	local is_absolute =
		--
		first_char == UNIX_SEPARATOR
		--
		or first_char == WINDOWS_SEPARATOR

	return setmetatable(
		--- @type neotest-java.Path
		{
			raw_path = raw_path,
			opts = opts or {},
			is_absolute = is_absolute,
			separator = SEP,
		},
		PATH_METATABLE
	)
end

--- Return the last segment of the path (file or directory name).
--- @return string
function Path:name()
	local slugs = self:slugs()
	return slugs[#slugs] or ""
end

--- Return the parent path.
--- @return neotest-java.Path
function Path:parent()
	local slugs = self:slugs()
	if self.is_absolute and #slugs == 2 then
		return Path(self.separator, self.opts)
	end
	return Path(vim.iter(slugs):take(#slugs - 1):join(self.separator), self.opts)
end

--- Append a segment to the path.
--- @param other string
--- @return neotest-java.Path
function Path:append(other)
	return Path(self.raw_path .. self.separator .. other, self.opts)
end

--- Make this path relative to a base path.
--- @param base_path neotest-java.Path
--- @return neotest-java.Path
function Path:make_relative(base_path)
	local this_string = self:to_string()
	local base_path_string = base_path:to_string()

	return Path(this_string:sub(#base_path_string + 2), self.opts)
end

--- Whether the path contains the given slug sequence.
--- @param slug_term string
--- @return boolean
function Path:contains(slug_term)
	local this_slugs = self:slugs()

	local other_slugs = Path(slug_term, self.opts):slugs()

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
end

--- Split the path into its segments.
--- @return string[]
function Path:slugs()
	local slugs = vim
		--
		.iter(vim.split(self.raw_path, WINDOWS_SEPARATOR))
		:map(function(s)
			return vim.split(s, UNIX_SEPARATOR)
		end)
		:flatten()
		:filter(is_not_empty)
		:filter(is_not_dot)
		:map(remove_separator)
		:totable()

	if self.is_absolute then
		table.insert(slugs, 1, "")
	end

	local has_relative_dot = self.raw_path:sub(1, 2) == "." .. UNIX_SEPARATOR
		or self.raw_path:sub(1, 2) == "." .. WINDOWS_SEPARATOR
	if has_relative_dot then
		table.insert(slugs, 1, ".")
	end

	return slugs
end

--- Render the path back to a string.
--- @return string
function Path:to_string()
	local slugs = self:slugs()
	if self.is_absolute and #slugs == 1 then
		return self.separator
	end

	if #slugs == 0 then
		return "."
	end
	return vim.iter(slugs):join(self.separator)
end

return setmetatable(Path --[[@as table]], {
	__call = function(_, ...)
		return Path.new(...)
	end,
})
