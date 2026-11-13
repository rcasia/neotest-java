local log = require("neotest-java.logger")
local JunitResult = require("neotest-java.model.junit_result")

local REPORT_FILE_NAMES_PATTERN = "TEST-.+%.xml$"

local clean_id = function(str)
	return str:gsub("%(.*", "")
end

--- @param tree neotest.Tree
--- @param id string
--- @return string | nil
local function matching_test_id(tree, id)
	if tree:get_key(id) then
		return id
	end

	local method_base = clean_id(id)
	return vim
		.iter(tree:iter())
		--- @param pos neotest.Position
		:map(function(_, pos)
			if pos.type == "test" then
				return pos.id
			end
		end)
		:find(function(pos_id)
			return clean_id(pos_id) == method_base
		end)
end

--- @return table <string, neotest-java.JunitResult[]>
local function group_by_method_base(testcases)
	local groups = {}
	for _, jres in ipairs(testcases) do
		local key = jres:id()
		groups[key] = groups[key] or {}
		table.insert(groups[key], jres)
	end
	return groups
end

-- -----------------------------------------------------------------------------
-- Public API
-- -----------------------------------------------------------------------------

--- @class neotest-java.StrategyResult : neotest.StrategyResult
--- @field error? string Strategy infrastructure/cancellation failure.

--- @class neotest-java.ResultBuilder
--- @field build_results fun(spec: neotest.RunSpec, result: neotest-java.StrategyResult, tree: neotest.Tree): table<string, neotest.Result>

--- @class neotest-java.ResultBuilderDeps
--- @field scan_dir fun(dir: neotest-java.Path, opts: { search_patterns: string[] }): neotest-java.Path[]
--- @field junit_result_reader { read_all: fun(paths: neotest-java.Path[]): neotest-java.JunitResult[] }
--- @field remove_file fun(filepath: string): boolean, string?
--- @field tempname_fn fun(): string

--- @param deps neotest-java.ResultBuilderDeps
--- @return neotest-java.ResultBuilder
local ResultBuilder = function(deps)
	deps = deps or {}
	assert(deps.scan_dir, "scan_dir should not be nil")
	assert(deps.junit_result_reader, "junit_result_reader should not be nil")
	assert(deps.remove_file, "remove_file should not be nil")
	assert(deps.tempname_fn, "tempname_fn should not be nil")

	local find_report_files = function(dir)
		return deps.scan_dir(dir, { search_patterns = { REPORT_FILE_NAMES_PATTERN } })
	end

	return {
		--- @param spec neotest.RunSpec
		--- @param result neotest-java.StrategyResult
		--- @param tree neotest.Tree
		--- @return table<string, neotest.Result>
		build_results = function(spec, result, tree)
			local function failure(message)
				return {
					status = "failed",
					output = result.output,
					short = message,
					errors = { { message = message } },
				}
			end
			local function failed_selection(message)
				local failures = {}
				for _, position in tree:iter() do
					if position.type == "test" then
						failures[position.id] = failure(message)
					end
				end
				if next(failures) == nil then
					failures[tree:data().id] = failure(message)
				end
				return failures
			end
			local function cleanup()
				if spec.context.cleanup_reports then
					spec.context.cleanup_reports()
				end
			end

			local process = spec.context.process
			local infrastructure_error = result.error
			if process then
				if infrastructure_error or (result.code ~= 0 and result.code ~= 1) then
					process.stop(infrastructure_error or "Debug strategy failed")
				end
				local state = process.wait_exit()
				infrastructure_error = infrastructure_error or state.error
				if state.cancelled or not state.exited then
					infrastructure_error = infrastructure_error or "Java debug test cancelled or timed out"
				elseif state.code ~= 0 and state.code ~= 1 then
					infrastructure_error = infrastructure_error
						or ("Java test exited with code " .. tostring(state.code))
				end
			end
			if infrastructure_error or (result.code ~= 0 and result.code ~= 1) then
				cleanup()
				return failed_selection(
					infrastructure_error or ("Test process exited with code " .. tostring(result.code))
				)
			end

			local report_files = find_report_files(spec.context.reports_dir)
			local read_ok, testcases = pcall(deps.junit_result_reader.read_all, report_files)
			if not read_ok then
				cleanup()
				return failed_selection("Could not read JUnit reports: " .. tostring(testcases))
			end
			local groups = group_by_method_base(testcases)

			local results = {}

			for id, items in pairs(groups) do
				if #items == 1 then
					--- @type neotest-java.JunitResult
					local jres = items[1]

					results[matching_test_id(tree, id) or id] = jres:result()
				else
					local _id = matching_test_id(tree, id)

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
			cleanup()

			-- Missing framework evidence is an infrastructure failure, never a
			-- pass or an inferred skip (including a partially reported selection).
			for _, position in tree:iter() do
				if position.type == "test" and not results[position.id] then
					results[position.id] = failure("No JUnit result reported for selected test: " .. position.id)
				end
			end
			if next(results) == nil then
				return failed_selection("No JUnit results found in " .. tostring(spec.context.reports_dir))
			end

			return results
		end,
	}
end

return ResultBuilder
