local read_file = require("neotest-java.util.read_file")

---Resolve the Java package name from a file.
---Returns "" if no package declaration is present.
---@param filename neotest-java.Path
---@return string
local function resolve_package_name(filename)
	local ok, content = pcall(function()
		return read_file(filename)
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
