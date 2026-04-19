local read_file_default = require("neotest-java.util.read_file")

---Resolve the Java package name from a file.
---Returns "" if no package declaration is present.
---@param filename neotest-java.Path
---@param read_file_fn? fun(path: neotest-java.Path): string  -- optional; defaults to neotest async reader
---@return string
local function resolve_package_name(filename, read_file_fn)
	read_file_fn = read_file_fn or read_file_default
	local ok, content = pcall(function()
		return read_file_fn(filename)
	end)
	if not ok then
		error(string.format("file does not exist: %s", filename))
	end

	-- Match: package com.example.foo;
	-- capture com.example.foo into %1
	local pkg = content:match("[\r\n]^%s*package%s+([%w_%.]+)%s*;%s*[\r\n]")
		or content:match("^%s*package%s+([%w_%.]+)%s*;") -- in case it's on the very first line
		or content:match("\n%s*package%s+([%w_%.]+)%s*;") -- general fallback
	return pkg or ""
end

return resolve_package_name
