local read_file = require("neotest-java.util.read_file")
local xml = require("neotest.lib.xml")

--- @param classname string name of class
--- @param testname string name of test
--- @return string unique_key based on classname and testname
local build_unique_key = function(classname, testname)
	return classname .. "::" .. testname
end

TestParser = {}

local function is_array(tbl)
	local index = 1
	for k, _ in pairs(tbl) do
		if k ~= index then
			return false
		end
		index = index + 1
	end
	return true
end

--- @param filename string
--- @return table { [test_name] = {
---   status = string,
---
--- { name = string,
---   status = string,
---   classname = string,
---   message = string }
--- }
---}
function TestParser.parse_html_gradle_report(filename)
	local test_classname = string.match(filename, "([^/]+)%.html")

	local ok, data = pcall(function()
		return read_file(filename)
	end)
	if not ok then
		return {}
	end

	local xml_data = xml.parse(data).html.body.div

	local summary = {}
	for _, div in ipairs(xml_data.div) do
		if div._attr.id == "tabs" then
			summary = div
		end
	end

	-- /html/body/div/div[id=tabs]/div[h2=Tests]/table/tbody/tr
	local table_rows = {}
	if not is_array(summary.div) then
		table_rows = summary.div.table.tr
	else
		for _, div in ipairs(summary.div) do
			if div.h2 == "Tests" then
				table_rows = div.table.tr
			end
		end
	end

	if not is_array(table_rows) then
		table_rows = { table_rows }
	end

	local testcases = {}
	for _, row in pairs(table_rows) do
		local columns = row.td
		if #columns == 4 then
			-- /html/body/div/div[id=tabs]/div[h2=Tests]/table/tbody/tr/td
			local name = columns[2][1]
			local status = columns[4][1]

			-- take out the parameterized part
			-- example: subtractAMinusBEqualsC(int, int, int)[1]
			-- becomes: subtractAMinusBEqualsC
			local short_name = string.match(name, "([^%(%[]+)")
			local unique_key = build_unique_key(test_classname, short_name)

			if testcases[unique_key] == nil then
				testcases[unique_key] = {
					status = "passed",
					{ name = name, status = status, classname = test_classname },
				}
			else
				table.insert(testcases[unique_key], { name = name, status = status, classname = test_classname })
			end
		end
	end

	-- /html/body/div/div[id=tabs]/div[h2=Failed tests]
	local failures = {}
	if is_array(summary.div) then
		for k, v in pairs(summary.div) do
			if v.h2 == "Failed tests" then
				failures = v.div
			end
		end
	end

	if not is_array(failures) then
		failures = { failures }
	end

	for k, v in pairs(failures) do
		local name = v.a._attr.name
		local short_name = string.match(name, "([^%(%[]+)")
		local parameters = v.h3[1]
		local message = v.span.pre
		-- takes just the first line of the message
		message = string.match(message, "([^\n]+)")

		local unique_key = build_unique_key(test_classname, short_name)
		if testcases[unique_key] ~= nil then
			for k2, v2 in pairs(testcases[unique_key]) do
				if v2.name == name then
					testcases[unique_key].status = "failed"
					testcases[unique_key][k2].message = message
				end
			end
		end
	end

	return testcases
end

return TestParser
