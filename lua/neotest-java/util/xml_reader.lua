--- @class neotest-java.XmlReaderDeps
--- @field read_file fun(filepath: string): string
--- @field xml_parse fun(xml_data: string): table

--- @class neotest-java.XmlReader
--- @field read_tag fun(self: neotest-java.XmlReader, filepath: string, selector: string): neotest-java.ReadResult

--- @class neotest-java.ReadResult
--- @field value string | nil
--- @field found boolean
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
	deps = deps or default_deps()

	return {
		--- Resolve a dotted-path selector against an XML file.
		--- Returns `{ value, found, error }` so callers can tell apart
		--- "tag missing" from "value is a complex node" from "I/O or parse error".
		--- @param filepath string
		--- @param selector string
		--- @return neotest-java.ReadResult
		read_tag = function(filepath, selector)
			local read_ok, content = pcall(deps.read_file, filepath)
			if not read_ok then
				return { value = nil, found = false, error = tostring(content) }
			end
			if type(content) ~= "string" then
				return { value = nil, found = false, error = "read_file did not return a string" }
			end

			local parse_ok, parsed = pcall(deps.xml_parse, content)
			if not parse_ok then
				return { value = nil, found = false, error = tostring(parsed) }
			end
			if type(parsed) ~= "table" then
				return { value = nil, found = false, error = "xml_parse did not return a table" }
			end

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
		end,
	}
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
