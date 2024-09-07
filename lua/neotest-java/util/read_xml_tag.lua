local memo = require("neotest.lib.func_util.memoize")
local file = require("neotest.lib.file")
local xml = require("neotest.lib.xml")

---@param filepath string
---@param selector string ex: project.build.sourceDirectory
---@return string | nil
local cache = {}
local read_xml_tag = memo(function(filepath, selector)
	local content = file.read(filepath)
	local parsed = xml.parse(content)

	for tag in string.gmatch(selector, "[^%.]+") do
		if not parsed[tag] then
			return nil
		end
		parsed = parsed[tag]
	end

	if type(parsed) == "table" then
		return nil
	end

	return parsed
end, cache)

return read_xml_tag
