local xml = require("neotest.lib.xml")
local flat_map = require("neotest-java.util.flat_map")
local log = require("neotest-java.logger")
local lib = require("neotest.lib")
local JunitResult = require("neotest-java.model.junit_result")

local REPORT_FILE_NAMES_PATTERN = "TEST-.+%.xml$"

local clean_id = function(str)
	return str:gsub("%(.*", "")
end

-- -----------------------------------------------------------------------------
-- XML loading
-- -----------------------------------------------------------------------------

--- @param read_file fun(path: neotest-java.Path): string
--- @param paths string[]
--- @param tempname? fun(): string
local function load_all_testcases(paths, read_file, tempname)
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
		return vim.iter(tcs)
			:map(function(tc)
				return { tc = tc, tempname = tempname }
			end)
			:totable()
	end, paths)
end

--- @return table <string, neotest-java.JunitResult[]>
local function group_by_method_base(testcases)
	local groups = {}
	for _, entry in ipairs(testcases) do
		local jres = JunitResult:new(entry.tc, entry.tempname)
		local key = jres:id()
		groups[key] = groups[key] or {}
		table.insert(groups[key], jres)
	end
	return groups
end

-- -----------------------------------------------------------------------------
-- Public API
-- -----------------------------------------------------------------------------

--- @class neotest-java.ResultBuilder
--- @field build_results fun(spec: neotest.RunSpec, result: neotest.StrategyResult, tree: neotest.Tree): table<string, neotest.Result>

--- @class neotest-java.ResultBuilderDeps
--- @field scan_dir fun(dir: neotest-java.Path, opts: { search_patterns: string[] }): neotest-java.Path[]
--- @field read_file fun(path: neotest-java.Path): string
--- @field remove_file fun(filepath: string): boolean, string?
--- @field tempname_fn fun(): string

--- @param deps neotest-java.ResultBuilderDeps
--- @return neotest-java.ResultBuilder
local ResultBuilder = function(deps)
	deps = deps or {}
	assert(deps.scan_dir, "scan_dir should not be nil")
	assert(deps.read_file, "read_file should not be nil")
	assert(deps.remove_file, "remove_file should not be nil")
	assert(deps.tempname_fn, "tempname_fn should not be nil")

	local find_report_files = function(dir)
		return deps.scan_dir(dir, { search_patterns = { REPORT_FILE_NAMES_PATTERN } })
	end

	return {
		--- @param spec neotest.RunSpec
		--- @param result neotest.StrategyResult
		--- @param tree neotest.Tree
		--- @return table<string, neotest.Result>
		build_results = function(spec, result, tree)
			if result.code ~= 0 and result.code ~= 1 then
				local node = tree:data()
				return { [node.id] = JunitResult.ERROR(node.id, result.output, deps.tempname_fn) }
			end

			if spec.context.strategy == "dap" then
				spec.context.terminated_command_event.wait()
			end

			local report_files = find_report_files(spec.context.reports_dir)
			local testcases = load_all_testcases(report_files, deps.read_file, deps.tempname_fn)
			local groups = group_by_method_base(testcases)

			local results = {}

			for id, items in pairs(groups) do
				if #items == 1 then
					--- @type neotest-java.JunitResult
					local jres = items[1]

					results[id] = jres:result()
				else
					local _id = vim
						.iter(tree:iter())
						--- @param pos neotest.Position
						:map(function(_, pos)
							return pos.id
						end)
						:find(function(pos_id)
							return clean_id(pos_id) == clean_id(items[1]:id())
						end)

					if _id then
						results[_id] = JunitResult.merge_results(items, deps.tempname_fn)
					else
						log.error("Could not find matching test node for results with id: " .. items[1]:id())
					end
				end
			end

			-- Clean up report files after processing
			for _, report_file in ipairs(report_files) do
				local filepath = tostring(report_file)
				local ok, err = deps.remove_file(filepath)
				if not ok then
					log.debug("Could not remove report file: " .. filepath .. " - " .. tostring(err or "unknown error"))
				end
			end

			return results
		end,
	}
end

return ResultBuilder
