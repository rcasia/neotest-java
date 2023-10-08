local context_manager = require("plenary.context_manager")
local with = context_manager.with
local open = context_manager.open
local xml = require("neotest.lib.xml")

TestParser = {}

function is_array(tbl)
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

	local data
	with(open(filename, "r"), function(reader)
		data = reader:read("*a")
	end)

	local xml_data = xml.parse(data).html.body.div.div[3]

	-- /html/body/div/div[3]/div/table/tbody/tr[1]/td[2]
	-- /html/body/div/div[3]/div[2]/table/tbody/tr[5]/td[2]
	-- /html/body/div/div[3]/div[2]/table/tbody/tr[1]/td[2]
	-- /html/body/div/div[3]/div/table/tbody/tr/td[1]
	-- /html/body/div/div[3]/div[2]/table/tbody/tr/td[2]
	local names
	if #xml_data.div == 0 then
		names = xml_data.div.table.tr
	else
		names = xml_data.div[2].table.tr
	end

	if not is_array(names) then
		names = { names }
	end

	local testcases = {}
	for k, v in pairs(names) do
		if #v.td == 4 then
			-- /html/body/div/div[3]/div[2]/table/tbody/tr[4]/td[2]
			-- /html/body/div/div[3]/div[2]/table/tbody/tr[5]/td[2]
			local name = v.td[2][1]
			-- local name = v.td[2][1]
			local status = v.td[4][1]

			-- take out the parameterized part
			-- example: subtractAMinusBEqualsC(int, int, int)[1]
			-- becomes: subtractAMinusBEqualsC
			short_name = string.match(name, "([^%(%[]+)")

			if testcases[short_name] == nil then
				testcases[short_name] = {
					status = "passed",
					{ name = name, status = status, classname = test_classname },
				}
			else
				table.insert(testcases[short_name], { name = name, status = status, classname = test_classname })
			end
		end
	end

	-- /html/body/div/div[3]/div[1]
	local failures
	if #xml_data.div == 0 then
		failures = {}
	else
		failures = xml_data.div[1].div
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

		for k2, v2 in pairs(testcases[short_name]) do
			if v2.name == name then
				testcases[short_name].status = "failed"
				testcases[short_name][k2].message = message
			end
		end
	end

	return testcases
end

TestResults = {}

function TestResults.get_status()
	local status = "passed"
	for k, v in pairs(TestResults.testcases) do
		for k2, v2 in pairs(v) do
			if v2.status == "failed" then
				status = "failed"
			end
		end
	end
	return status
end

return TestParser
