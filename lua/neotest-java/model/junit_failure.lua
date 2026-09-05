--- @class neotest-java.JunitFailure
--- @field failure_message string
--- @field failure_output string | nil

local M = {}

---@param output string | nil
---@param fallback? string
---@return string
local function failure_message_from_output(output, fallback)
	if type(output) ~= "string" then
		return fallback or "<unknown failure>"
	end

	local first_line = output:match("^%s*([^\n]+)")
	if not first_line then
		return fallback or "<unknown failure>"
	end

	return first_line:match("^[%w%._$]+:%s*(.+)$") or first_line
end

--- Parses a `failure` or `error` XML node (as produced by the JUnit XML
--- reader) into a normalized `{failure_message, failure_output}` shape.
---
--- JUnit XML failure/error nodes can appear in several shapes depending on
--- the xml parser and the report itself:
--- - a scalar (string) node
--- - a node with a `_attr` table (single failure with `message`/`type` attrs)
--- - an array-like node without `_attr` (ambiguous parsing quirk, see below)
---
---@param node table | string
---@return neotest-java.JunitFailure
function M.from_node(node)
	if type(node) ~= "table" then
		local output = tostring(node)
		return {
			failure_message = failure_message_from_output(output),
			failure_output = output,
		}
	end

	if node._attr then
		return {
			failure_message = node._attr.message or node._attr.type or "<unknown failure>",
			failure_output = node[1],
		}
	end

	-- This is not parsed correctly by the xml library
	-- <failure message="expected: &lt;1> but was: &lt;2>" type="org.opentest4j.AssertionFailedError">
	-- it breaks in the first '>'
	-- so it does not detect the message attribute sometimes
	local output = type(node[#node]) == "string" and node[#node] or nil
	local fallback = type(node[1]) == "string" and node[1]:match('type="([^"]+)"') or nil
	return {
		failure_message = failure_message_from_output(output, fallback),
		failure_output = output,
	}
end

--- Scrapes the 0-indexed line number of the failing test from a stack trace,
--- matching against the given fully-qualified `classname`.
---
---@param failure_output string | nil
---@param classname string
---@return integer | nil
function M.line_number(failure_output, classname)
	if not failure_output then
		return nil
	end

	local filename = string.match(classname, "[%.]?([%a%$_][%a%d%$_]+)$") .. ".java"
	local line_searchpattern = string.gsub(filename, "%.", "%%.") .. ":(%d+)%)"

	local line = string.match(failure_output, line_searchpattern)
	-- NOTE: errors array is expecting lines properties to be 0 index based
	return line and line - 1 or nil
end

return M
