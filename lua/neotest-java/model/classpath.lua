--- @class neotest-java.ClasspathOpts
--- @field separator? string Entry separator. Defaults to ";" on Windows, ":" on Unix.

--- @class neotest-java.Classpath
--- @field entries string[] The raw classpath entries, in order.
--- @field separator string The separator used to join entries.
--- @overload fun(entries?: (string | neotest-java.Path)[], opts?: neotest-java.ClasspathOpts): neotest-java.Classpath
local Classpath = {}

local CLASSPATH_METATABLE = {

	__index = Classpath,
	__tostring = function(classpath)
		return classpath:to_string()
	end,

	--- @param left neotest-java.Classpath
	--- @param right neotest-java.Classpath
	__eq = function(left, right)
		-- check if both are actually tables to avoid errors
		if type(left) ~= "table" or type(right) ~= "table" then
			return false
		end
		return left:to_string() == right:to_string()
	end,
}

local DEFAULT_SEPARATOR = vim.fn.has("win32") == 1 and ";" or ":"

--- @param entry string | neotest-java.Path
--- @return string
local entry_to_string = function(entry)
	return tostring(entry)
end

--- Create a new Classpath instance.
--- Preserves entry order exactly (no deduplication, no filtering),
--- mirroring how the entries were collected from the language server.
--- @param entries? (string | neotest-java.Path)[] Classpath entries, in order.
--- @param opts? neotest-java.ClasspathOpts
--- @return neotest-java.Classpath
function Classpath.new(entries, opts)
	local strings = vim.iter(entries or {}):map(entry_to_string):totable()
	return setmetatable(
		--- @type neotest-java.Classpath
		{
			entries = strings,
			separator = (opts and opts.separator) or DEFAULT_SEPARATOR,
		},
		CLASSPATH_METATABLE
	)
end

--- Join the entries with the separator.
--- @return string
function Classpath:to_string()
	return table.concat(self.entries, self.separator)
end

--- Whether there are no entries.
--- @return boolean
function Classpath:is_empty()
	return #self.entries == 0
end

--- Return a new Classpath with one entry appended.
--- @param entry string | neotest-java.Path
--- @return neotest-java.Classpath
function Classpath:append(entry)
	return Classpath.new(
		vim.iter({ self.entries, { entry_to_string(entry) } }):flatten():totable(),
		{ separator = self.separator }
	)
end

--- Return a new Classpath concatenating two classpaths.
--- Uses this instance's separator.
--- @param other neotest-java.Classpath
--- @return neotest-java.Classpath
function Classpath:merge(other)
	return Classpath.new(vim.iter({ self.entries, other.entries }):flatten():totable(), { separator = self.separator })
end

--- @type neotest-java.Classpath
local ClasspathStruct = setmetatable(Classpath --[[@as table]], {
	__call = function(_, ...)
		return Classpath.new(...)
	end,
})

return ClasspathStruct
