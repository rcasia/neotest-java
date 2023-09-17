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

function is_parametrized_test(testcases, name)
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

  print("count", count)
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
	local runned_testcases = {}

	for _, file in ipairs(files) do
		if string.find(file, ".xml", 1, true) then
			local data
			with(open(file, "r"), function(reader)
				data = reader:read("*a")
			end)

			local xml_data = xml.parse(data)

			local runned_testcases_in_xml = xml_data.testsuite.testcase

			-- index table if not array
			if not isIndexedTable(runned_testcases_in_xml) then
				runned_testcases_in_xml = { runned_testcases_in_xml }
			end

			if not runned_testcases_in_xml then
				-- TODO: use an actual logger
				print("[neotest-java] No test cases found")
				break
			else
				-- runned_testcases_in_xml is an array
				for _, testcase in ipairs(runned_testcases_in_xml) do
					runned_testcases[testcase._attr.name] = testcase
				end
			end
		end
	end

  print("runned_testcases", vim.inspect(runned_testcases))

	for _, v in tree:iter_nodes() do
		local node_data = v:data()
    local name = node_data.name
    local type = node_data.type
    local id = node_data.id
    local is_not_test = type ~= "test"
    local is_parameterized_test = is_parametrized_test(runned_testcases, name)

    print("node_data", vim.inspect(node_data))

    -- filter out non-test nodes
    if is_not_test then
      print("is_not_test hit for", name)
      return
    end

		if is_parameterized_test then
      print("parameterized hit for", name)
    else
      print("not parameterized hit for", name)
			local test_case = runned_testcases[name]

      print("test_case", vim.inspect(test_case))

      print("node_data.name", vim.inspect(name))

			if not test_case then
        print("skipped hit for", name)
				results[id] = {
					status = "skipped",
				}
			elseif test_case.failure ~= nil then
				results[id] = {
					status = "failed",
				}
			else
        print("passed hit for", name)
				results[id] = {
					status = "passed",
				}
			end
		end
	end

	return results
end

return ResultBuilder
