local M = {}

--- Recursively convert a table to a formatted string with indentation.
---@param value any
---@param indent? integer
---@return string
local function pretty(value, indent)
	indent = indent or 0
	local t = type(value)

	if t == "table" then
		local pad = string.rep("  ", indent)
		local buf = { "{" }
		for k, v in pairs(value) do
			local key_str = tostring(k)
			local val_str = pretty(v, indent + 1)
			table.insert(buf, string.format("\n%s  [%s] = %s", pad, key_str, val_str))
		end
		table.insert(buf, "\n" .. pad .. "}")
		return table.concat(buf, "")
	elseif t == "string" then
		return string.format("%q", value)
	else
		return tostring(value)
	end
end

--- Deep equality comparison
---@param a any
---@param b any
---@return boolean
local function deep_equal(a, b)
	if a == b then
		return true
	end
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return false
	end

	local seen = {}
	for k in pairs(a) do
		seen[k] = true
		if not deep_equal(a[k], b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if not seen[k] then
			return false
		end
	end
	return true
end

--- Assert that two values are deeply equal, printing full diff if not.
---@param expected any
---@param actual any
---@param msg? string
function M.eq(expected, actual, msg)
	if not deep_equal(expected, actual) then
		local err = string.format(
			"%s\nExpected:\n%s\n\nGot:\n%s",
			msg or "Assertion failed (tables not equal):",
			pretty(expected),
			pretty(actual)
		)
		error(err, 2)
	end
end

return M
