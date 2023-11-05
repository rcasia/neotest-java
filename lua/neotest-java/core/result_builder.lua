local xml = require("neotest.lib.xml")
local scan = require("plenary.scandir")
local context_manager = require("plenary.context_manager")
local with = context_manager.with
local open = context_manager.open
local test_parser = require("neotest-java.util.test_parser")

--- @param classname string name of class
--- @param testname string name of test
--- @return string unique_key based on classname and testname
local build_unique_key = function(classname, testname)
	return classname .. "::" .. testname
end

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

	-- TODO: indeed if the regex match just one time,
	-- it is a parameterized test of one test case
	-- so this for loop is not necessary
	for k, _ in pairs(testcases) do
		if string.match(k, regex) then
			count = count + 1
		end

		if count >= 1 then
			return true
		end
	end

	return false
end

function extract_test_failures(testcases, name)
	-- regex to match the name with some parameters and index at the end
	-- example: subtractAMinusBEqualsC(int, int, int)[1]
	local regex = name .. "%(([^%)]+)%)%[([%d]+)%]"

	failures = {}
	for k, v in pairs(testcases) do
		if string.match(k, regex) then
			if v.failure then
				failures[#failures + 1] = v
			end
		end
	end

	return failures
end

function read_testcases_from_html(test_method_names, cwd, test_file_name)
	local testcases = {}

	local dir = cwd .. "/build/reports/tests/test/classes"
	local filenames = scan.scan_dir(dir, { depth = 1 })

	local testcases_from_html = {}
	for _, filename in ipairs(filenames) do
		if string.find(filename, test_file_name .. ".html", 1, true) then
			testcases_from_html = test_parser.parse_html_gradle_report(filename)
		end
	end

	for _, test_method_name in ipairs(test_method_names) do
		local unique_key = build_unique_key(test_file_name, test_method_name)
		result = testcases_from_html[unique_key] or {}
		if result.status == "failed" then
			for _, res in ipairs(result) do
				if res.status == "failed" then
					testcases[build_unique_key(res.classname, res.name)] = {
						failure = { res.message },
						_attr = {
							name = res.name,
						},
					}
				end
			end
		else
			for _, res in ipairs(result) do
				testcases[build_unique_key(res.classname, res.name)] = {
					_attr = {
						name = res.message,
					},
				}
			end
		end
	end

	return testcases
end

ResultBuilder = {}

---@class neotest.Result
---@field status "passed"|"failed"|"skipped"
---@field output? string Path to file containing full output data
---@field short? string Shortened output string
---@field errors? neotest.Error[]

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function ResultBuilder.build_results(spec, result, tree)
	local results = {}

	local project_type = spec.context.project_type
	local test_file_name = spec.context.test_class_path

	local reports_dir = ""
	if project_type == "maven" then
		reports_dir = spec.cwd .. "/target/surefire-reports"
	elseif project_type == "gradle" then
		reports_dir = spec.cwd .. "/build/test-results/test"
	end

	local testcases = {}

	local test_method_names = spec.context.test_method_names
	if project_type == "gradle" and test_method_names and #test_method_names > 0 then
		testcases_from_html = read_testcases_from_html(spec.context.test_method_names, spec.cwd, test_file_name)
		testcases = testcases_from_html
	end

	local files = scan.scan_dir(reports_dir, { depth = 1 })

	for _, file in ipairs(files) do
		if string.find(file, test_file_name .. ".xml", 1, true) then
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
					local name = testcase._attr.name

					if project_type == "gradle" then
						-- remove parameters
						name = name:gsub("%(.*%)", "")
					end

					testcases[build_unique_key(test_file_name, name)] = testcase
				end
			end
		end
	end

	for _, v in tree:iter_nodes() do
		local node_data = v:data()
		local is_test = node_data.type == "test"
		local unique_key = build_unique_key(test_file_name, node_data.name)
		local is_parameterized = is_parameterized_test(testcases, node_data.name)

		if is_test then
			if is_parameterized then
				-- TODO: use an actual logger
				-- print("[neotest-java] parameterized test: " .. node_data.name)

				local test_failures = extract_test_failures(testcases, unique_key)

				local short_failure_messages = {}
				for _, failure in ipairs(test_failures) do
					failure_message = failure.failure[1]
					name = failure._attr.name
					-- take just the first line of the failure message
					short_failure_message = name .. " -> " .. failure_message:gsub("\n.*", "")
					short_failure_messages[#short_failure_messages + 1] = short_failure_message
				end

				-- sort the messages alphabetically
				table.sort(short_failure_messages)

				local message = table.concat(short_failure_messages, "\n")
				if #test_failures > 0 then
					results[node_data.id] = {
						status = "failed",
						short = message,
						errors = { { message = message } },
					}
				else
					results[node_data.id] = {
						status = "passed",
					}
				end
			else
				local test_case = testcases[unique_key]

				if not test_case then
					results[node_data.id] = {
						status = "skipped",
					}
				elseif test_case.error then
					local message = test_case.error._attr.message
					results[node_data.id] = {
						status = "failed",
						short = message,
						errors = { { message = message } },
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
