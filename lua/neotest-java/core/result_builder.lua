local xml = require("neotest.lib.xml")
local read_file = require("neotest-java.util.read_file")
local resolve_qualified_name = require("neotest-java.util.resolve_qualified_name")
local log = require("neotest-java.logger")
local nio = require("nio")

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

local function extract_test_failures(testcases, name)
	-- regex to match the name with some parameters and index at the end
	-- example: subtractAMinusBEqualsC(int, int, int)[1]
	local regex = name .. "[%(%.%{]?.*%[%d+%]$"

	local failures = {}
	local passes = {}
	for k, v in pairs(testcases) do
		if string.match(k, regex) then
			if v.failure then
				failures[#failures + 1] = v
			else
				passes[#passes + 1] = v
			end
		end
	end

	return failures, passes
end

local LINE_SEPARATOR = "=================================\n"

---@param data string | string[] | table
---@return string | nil filepath
local function create_file_with_content(data)
	if not data then
		return nil
	end

	if type(data) == "table" then
		data = vim.iter(data):flatten(math.huge):totable()
		data = table.concat(data, LINE_SEPARATOR)
	end

	-- Generate a unique temporary file name
	local filepath = nio.fn.tempname()

	nio.run(function()
		-- Open the file in write mode
		local file = assert(io.open(filepath, "w"))

		file:write(data)

		-- Close the file
		file:close()
	end)

	-- Return the path to the file
	return filepath
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

	local results = {}

	local testcases = {}

	local filename = spec.context.report_file or "/tmp/neotest-java/TEST-junit-jupiter.xml"
	local ok, data = pcall(function()
		return read_file(filename)
	end)
	if not ok then
		print("Error reading file: " .. filename)
		return {}
	end
	log.debug("Test report file: " .. filename)

	local xml_data = xml.parse(data)

	local testcases_in_xml = xml_data.testsuite.testcase
	if not is_array(testcases_in_xml) then
		testcases_in_xml = { testcases_in_xml }
	end

	for _, testcase in ipairs(testcases_in_xml) do
		local name = testcase._attr.name
		local classname = testcase._attr.classname

		name = name:gsub("%(.*%)", "")
		local unique_key = build_unique_key(classname, name)
		testcases[unique_key] = testcase
	end

	for _, v in tree:iter_nodes() do
		local node_data = v:data()
		local is_test = node_data.type == "test"
		local is_parameterized = is_parameterized_test(testcases, node_data.name)

		if is_test then
			local unique_key = build_unique_key(resolve_qualified_name(node_data.path), node_data.name)

			if is_parameterized then
				local test_failures, passes = extract_test_failures(testcases, unique_key)
				local system_out = {}
				for _, pass in ipairs(passes) do
					system_out[#system_out + 1] = table.concat(pass["system-out"], LINE_SEPARATOR)
				end

				local short_failure_messages = {}
				local long_failure_messages = {}
				for _, failure in ipairs(test_failures) do
					local failure_message = failure.failure[1]
					local name = failure._attr.name
					-- take just the first line of the failure message
					local short_failure_message = name .. " -> " .. failure_message:gsub("\n.*", "")
					short_failure_messages[#short_failure_messages + 1] = short_failure_message
					long_failure_messages[#long_failure_messages + 1] = table.concat(
						failure["system-out"],
						LINE_SEPARATOR
					) .. LINE_SEPARATOR .. failure_message
				end

				for _, lfm in ipairs(long_failure_messages) do
					system_out[#system_out + 1] = lfm
				end

				-- sort the messages alphabetically
				table.sort(short_failure_messages)
				table.sort(system_out)

				local message = table.concat(short_failure_messages, "\n")
				if #test_failures > 0 then
					results[node_data.id] = {
						status = "failed",
						short = message,
						errors = { { message = message } },
						output = create_file_with_content(system_out),
					}
				else
					results[node_data.id] = {
						status = "passed",
						output = create_file_with_content(system_out),
					}
				end
			else
				local test_case = testcases[unique_key]

				if not test_case then
					results[node_data.id] = {
						status = "skipped",
						output = create_file_with_content({ node_data.id, "This test was not executed." }),
					}
				elseif test_case.error then
					local message = test_case.error._attr.message
					results[node_data.id] = {
						status = "failed",
						short = message,
						errors = { { message = message } },
						output = create_file_with_content({ test_case["system-out"], test_case.error[1] }),
					}
				elseif test_case.failure then
					local message = test_case.failure._attr.message
					local filename = string.match(test_case._attr.classname, "[%.]?([%a%$_][%a%d%$_]+)$") .. ".java"
					local line_searchpattern = string.gsub(filename, "%.", "%%.") .. ":(%d+)%)"
					local line = string.match(test_case.failure[1], line_searchpattern)
					-- NOTE: errors array is expecting lines properties to be 0 index based
					if line ~= nil then
						line = line - 1
					end
					results[node_data.id] = {
						status = "failed",
						short = message,
						errors = { { message = message, line = line } },
						output = create_file_with_content({ test_case["system-out"], test_case.failure[1] }),
					}
				else
					results[node_data.id] = {
						status = "passed",
						output = create_file_with_content(test_case["system-out"]),
					}
				end
			end
		end
	end

	return results
end

return ResultBuilder
