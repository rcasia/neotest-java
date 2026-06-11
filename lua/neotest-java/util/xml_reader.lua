--- @class neotest-java.XmlReaderDeps
--- @field read_file? fun(filepath: string): string
--- @field xml_parse? fun(xml_data: string): table

--- @class neotest-java.XmlReader
--- @field parse fun(filepath: string): neotest-java.ParseResult
--- @field read_tag fun(filepath: string, selector: string): neotest-java.ReadResult

--- @class neotest-java.ReadResult
--- @field value string | nil
--- @field found boolean
--- @field error string | nil

--- @class neotest-java.ParseResult
--- @field tree table | nil
--- @field error string | nil

local NEOTEST_FILE = "neotest.lib.file"
local NEOTEST_XML = "neotest.lib.xml"

--- Build the default dependency table for the reader.
--- Lazy-loads neotest.lib.file and neotest.lib.xml so unit tests
--- that inject custom deps never trigger the real requires.
--- @return neotest-java.XmlReaderDeps
local function default_deps()
	return {
		read_file = require(NEOTEST_FILE).read,
		xml_parse = require(NEOTEST_XML).parse,
	}
end

--- Parse the dotted-path selector into a list of segment names.
--- Splits on "." (e.g. "project.build.directory" -> { "project", "build", "directory" }).
--- @param selector string
--- @return string[]
local function split_selector(selector)
	local segments = {}
	for segment in string.gmatch(selector, "[^%.]+") do
		segments[#segments + 1] = segment
	end
	return segments
end

--- @param deps neotest-java.XmlReaderDeps | nil
--- @return neotest-java.XmlReader
local XmlReader = function(deps)
	deps = deps or {}
	local defaults = default_deps()
	deps.read_file = deps.read_file or defaults.read_file
	deps.xml_parse = deps.xml_parse or defaults.xml_parse

	local instance = {}

	--- Read and parse an XML file, returning the full parsed tree
	--- (or an error). Use this when callers need to walk the tree
	--- themselves (arrays of testcases, etc.) rather than resolve
	--- a single scalar at a dotted-path.
	--- @param filepath string
	--- @return neotest-java.ParseResult
	function instance.parse(filepath)
		local read_ok, content = pcall(deps.read_file, filepath)
		if not read_ok then
			return { tree = nil, error = tostring(content) }
		end
		if type(content) ~= "string" then
			return { tree = nil, error = "read_file did not return a string" }
		end

		local parse_ok, parsed = pcall(deps.xml_parse, content)
		if not parse_ok then
			return { tree = nil, error = tostring(parsed) }
		end
		if type(parsed) ~= "table" then
			return { tree = nil, error = "xml_parse did not return a table" }
		end

		return { tree = parsed, error = nil }
	end

	--- Resolve a dotted-path selector against an XML file.
	--- Returns `{ value, found, error }` so callers can tell apart
	--- "tag missing" from "value is a complex node" from "I/O or parse error".
	--- @param filepath string
	--- @param selector string
	--- @return neotest-java.ReadResult
	function instance.read_tag(filepath, selector)
		local parsed_result = instance.parse(filepath)
		if parsed_result.error then
			return { value = nil, found = false, error = parsed_result.error }
		end

		local parsed = parsed_result.tree
		for _, tag in ipairs(split_selector(selector)) do
			if type(parsed) ~= "table" then
				return { value = nil, found = false, error = nil }
			end
			local next_node = parsed[tag]
			if next_node == nil then
				return { value = nil, found = false, error = nil }
			end
			parsed = next_node
		end

		if type(parsed) == "table" then
			return { value = nil, found = false, error = nil }
		end

		return { value = parsed, found = true, error = nil }
	end

	return instance
end

local default_reader = XmlReader()

return {
	new = XmlReader,
	read_tag = function(filepath, selector)
		local result = default_reader.read_tag(filepath, selector)
		if result.found then
			return result.value
		end
		return nil
	end,
}
