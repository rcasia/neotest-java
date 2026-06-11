local memo = require("neotest.lib.func_util.memoize")
local XmlReader = require("neotest-java.util.xml_reader").new

--- @param filepath string
--- @param selector string ex: project.build.sourceDirectory
--- @return string | nil
local function _read_xml_tag(filepath, selector)
	local reader = XmlReader()
	local result = reader.read_tag(filepath, selector)
	if result.found then
		return result.value
	end
	return nil
end

local read_xml_tag = memo(_read_xml_tag)

return read_xml_tag
