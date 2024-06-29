local xml = require("neotest.lib.xml")
local read_file = require("neotest-java.util.read_file")
local resolve_qualified_name = require("neotest-java.util.resolve_qualified_name")
local log = require("neotest-java.logger")
local nio = require("nio")
local JunitResult = require("neotest-java.core.junit_result")
local SKIPPED = JunitResult.SKIPPED

--- @param classname string name of class
--- @param testname string name of test
--- @return string unique_key based on classname and testname
local build_unique_key = function(classname, testname)
	return classname .. "::" .. testname
end

local function is_array(tbl)
	if not tbl then
		return false
	end
	local index = 1
	for k, _ in pairs(tbl) do
		if k ~= index then
			return false
		end
		index = index + 1
	end
	return true
end

local function is_parameterized_test(testcases, name)
	-- regex to match the name with some parameters and index at the end
	-- example: subtractAMinusBEqualsC(int, int, int)[1]
	local regex = name .. "[%(%.%{]?.*%[%d+%]$"

	for k, _ in pairs(testcases) do
		if string.match(k, regex) then
			return true
		end
	end

	return false
end

---@return neotest-java.JunitResult[]
local function extract_parameterized_tests(testcases, name)
	-- regex to match the name with some parameters and index at the end
	-- example: subtractAMinusBEqualsC(int, int, int)[1]
	local regex = name .. "[%(%.%{]?.*%[%d+%]$"

	local tests = {}
	for k, v in pairs(testcases) do
		if string.match(k, regex) then
			tests[#tests + 1] = JunitResult:new(v)
		end
	end

	return tests
end

ResultBuilder = {}

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function ResultBuilder.build_results(spec, result, tree)
	-- wait for the debug test to finish
	if spec.context.strategy == "dap" then
		spec.context.terminated_command_event.wait()
	end

	---@type table<string, neotest.Result>
	local results = {}

	local testcases = {}
	---@type table<string, neotest-java.JunitResult>
	local testcases_junit = {}

	local filename = spec.context.report_file or "/tmp/neotest-java/TEST-junit-jupiter.xml"
	local ok, data = pcall(function()
		return read_file(filename)
	end)
	if not ok then
		vim.notify("Error reading file: " .. filename)
		return {}
	end
	log.debug("Test report file: " .. filename)

	local xml_data = xml.parse(data)

	local testcases_in_xml = xml_data.testsuite.testcase
	if not is_array(testcases_in_xml) then
		testcases_in_xml = { testcases_in_xml }
	end

	for _, testcase in ipairs(testcases_in_xml) do
		local jresult = JunitResult:new(testcase)
		local name = jresult:name()
		local classname = jresult:classname()

		name = name:gsub("%(.*%)", "")
		local unique_key = build_unique_key(classname, name)
		testcases[unique_key] = testcase
		testcases_junit[unique_key] = jresult
	end

	for _, node in tree:iter() do
		local is_test = node.type == "test"
		local is_parameterized = is_parameterized_test(testcases, node.name)

		if not is_test then
			goto continue
		end

		local unique_key = build_unique_key(resolve_qualified_name(node.path), node.name)

		if is_parameterized then
			local jtestcases = extract_parameterized_tests(testcases, unique_key)
			results[node.id] = JunitResult.merge_results(jtestcases)
		else
			local jtestcase = testcases_junit[unique_key]

			if not jtestcase then
				results[node.id] = SKIPPED(node.id)
			else
				results[node.id] = jtestcase:result()
			end
		end

		::continue::
	end

	return results
end

return ResultBuilder
