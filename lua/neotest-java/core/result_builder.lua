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
	local test_cases = {}

	for _, file in ipairs(files) do
		if string.find(file, ".xml", 1, true) then
			local data
			with(open(file, "r"), function(reader)
				data = reader:read("*a")
			end)

			local xml_data = xml.parse(data)

			for _, testcase in ipairs(xml_data.testsuite.testcase) do
				test_cases[testcase._attr.name] = testcase
			end
		end
	end

	for _, v in tree:iter_nodes() do
		local node_data = v:data()
		if node_data.type == "test" then
			local test_case = test_cases[node_data.name]

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

	return results
end

return ResultBuilder
