local xml = require("neotest.lib.xml")
local flat_map = require("neotest-java.util.flat_map")
local log = require("neotest-java.logger")
local lib = require("neotest.lib")
local JunitResult = require("neotest-java.model.junit_result")
local dir_scan = require("neotest-java.util.dir_scan")

local REPORT_FILE_NAMES_PATTERN = "TEST-.+%.xml$"

-- -----------------------------------------------------------------------------
-- XML loading
-- -----------------------------------------------------------------------------

--- @param read_file fun(path: neotest-java.Path): string
--- @param paths string[]
local function load_all_testcases(paths, read_file)
	log.debug("Found report files: ", paths)
	if #paths == 0 then
		return {}
	end

	return flat_map(function(filepath)
		local ok, data = pcall(read_file, filepath)
		if not ok then
			log.error("Error reading file: " .. tostring(filepath))
			lib.notify("Error reading file: " .. tostring(filepath))
			return {}
		end

		local xml_data = xml.parse(data)
		local suite = xml_data and xml_data.testsuite or nil
		if not suite then
			return {}
		end

		local tcs = suite.testcase
		if not tcs then
			return {}
		end
		if not vim.isarray(tcs) then
			tcs = { tcs }
		end
		return tcs
	end, paths)
end

local function group_by_method_base(testcases)
	local groups = {}
	for _, tc in ipairs(testcases) do
		local jres = JunitResult:new(tc)
		local key = jres:id()
		groups[key] = groups[key] or {}
		table.insert(groups[key], jres)
	end
	return groups
end

-- -----------------------------------------------------------------------------
-- Public API
-- -----------------------------------------------------------------------------

local ResultBuilder = {}

--- @param read_file fun(path: neotest-java.Path): string
--- @param tree neotest.Tree
--- @param scan fun(dir: neotest-java.Path, opts: { search_patterns: string[] }): string[]
function ResultBuilder.build_results(spec, result, tree, scan, read_file)
	scan = scan or dir_scan
	read_file = read_file or require("neotest-java.util.read_file")

	if result.code ~= 0 and result.code ~= 1 then
		local node = tree:data()
		return { [node.id] = JunitResult.ERROR(node.id, result.output) }
	end

	if spec.context.strategy == "dap" then
		spec.context.terminated_command_event.wait()
	end

	local testcases = load_all_testcases(
		scan(spec.context.reports_dir, { search_patterns = { REPORT_FILE_NAMES_PATTERN } }),
		read_file
	)
	local groups = group_by_method_base(testcases)

	local results = {}

	for id, items in pairs(groups) do
		--- remove iterative test suffix for result mapping
		--- from: testMethod()[1]
		--- to:   testMethod()
		local _id = id:gsub("%[%d+%]", "")

		if #items == 1 then
			--- @type neotest-java.JunitResult
			local jres = items[1]
			results[_id] = jres:result()
		else
			results[_id] = JunitResult.merge_results(items)
			print(vim.inspect({ pos_id = tree:data().id, id = _id, results = results }))
		end
	end

	return results
end

return ResultBuilder
