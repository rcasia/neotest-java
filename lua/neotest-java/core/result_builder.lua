---@class neotest.Result
---@field status "passed"|"failed"|"skipped"
---@field output? string Path to file containing full output data
---@field short? string Shortened output string
---@field errors? neotest.Error[]

local xml = require("neotest.lib.xml")
local scan = require("plenary.scandir")
local context_manager = require("plenary.context_manager")
local with = context_manager.with
local open = context_manager.open

function isIndexedTable(tbl)
	local index = 1
	for k, _ in pairs(tbl) do
		if k ~= index then
			return false
		end
		index = index + 1
	end
	return true
end

function is_parameterized_test(testcases, name)
	local count = 0
	-- regex to match the name with some parameters and index at the end
	-- example: subtractAMinusBEqualsC(int, int, int)[1]
	local regex = name .. "%(([^%)]+)%)%[([%d]+)%]"

	for k, _ in pairs(testcases) do
		if string.match(k, regex) then
			count = count + 1
		end

		if count > 1 then
			return true
		end
	end

	return false
end

function any_contains_test_failure(testcases, name)
	-- regex to match the name with some parameters and index at the end
	-- example: subtractAMinusBEqualsC(int, int, int)[1]
	local regex = name .. "%(([^%)]+)%)%[([%d]+)%]"

	for k, v in pairs(testcases) do
		if string.match(k, regex) then
			if v.failure then
				return true
			end
		end
	end

	return false
end

ResultBuilder = {}

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function ResultBuilder.build_results(spec, result, tree)
	local results = {}

	local reports_dir = spec.cwd .. "/target/surefire-reports"
	local files = scan.scan_dir(reports_dir, { depth = 1 })
	local testcases = {}

	for _, file in ipairs(files) do
		if string.find(file, ".xml", 1, true) then
			local data
			with(open(file, "r"), function(reader)
				data = reader:read("*a")
			end)

			local xml_data = xml.parse(data)

			local testcases_in_xml = xml_data.testsuite.testcase

			-- index table if not array
			if not isIndexedTable(testcases_in_xml) then
				testcases_in_xml = { testcases_in_xml }
			end

			if not testcases_in_xml then
				-- TODO: use an actual logger
				print("[neotest-java] No test cases found")
				break
			else
				-- testcases_in_xml is an array
				for _, testcase in ipairs(testcases_in_xml) do
					testcases[testcase._attr.name] = testcase
				end
			end
		end
	end

	for _, v in tree:iter_nodes() do
		local node_data = v:data()
		local is_test = node_data.type == "test"
		local is_parameterized = is_parameterized_test(testcases, node_data.name)

		if is_test then
			if is_parameterized then
				print("[neotest-java] parameterized test: " .. node_data.name)

				local result = any_contains_test_failure(testcases, node_data.name)

				if result then
					results[node_data.id] = {
						status = "failed",
					}
				else
					results[node_data.id] = {
						status = "passed",
					}
				end
			else
				local test_case = testcases[node_data.name]

				if not test_case then
					results[node_data.id] = {
						status = "skipped",
					}
				elseif test_case.failure then
					results[node_data.id] = {
						status = "failed",
					}
				else
					results[node_data.id] = {
						status = "passed",
					}
				end
			end
		end
	end

	return results
end

return ResultBuilder
