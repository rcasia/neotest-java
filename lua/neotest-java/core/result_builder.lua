local log = require("neotest-java.logger")
local JunitResult = require("neotest-java.model.junit_result")
local OutputWriter = require("neotest-java.util.output_writer")

local REPORT_FILE_NAMES_PATTERN = "TEST-.+%.xml$"

local clean_id = function(str)
	return str:gsub("%(.*", "")
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

--- Converts `JunitResult`/`JunitResult.merge_results`'s plain result data
--- into a `neotest.Result`, writing `output_lines` to disk via the
--- injected `output_writer`. This is the only place in the results flow
--- that touches a real (or stubbed) `output_writer`.
--- @param data neotest-java.JunitResultData
--- @param output_writer neotest-java.OutputWriter
--- @return neotest.Result
local function to_neotest_result(data, output_writer)
	return {
		status = data.status,
		short = data.short,
		errors = data.errors,
		output = output_writer.write(data.output_lines),
	}
end

-- -----------------------------------------------------------------------------
-- Public API
-- -----------------------------------------------------------------------------

--- @class neotest-java.ResultBuilder
--- @field build_results fun(spec: neotest.RunSpec, result: neotest.StrategyResult, tree: neotest.Tree): table<string, neotest.Result>

--- @class neotest-java.ResultBuilderDeps
--- @field scan_dir fun(dir: neotest-java.Path, opts: { search_patterns: string[] }): neotest-java.Path[]
--- @field junit_result_reader { read_all: fun(paths: neotest-java.Path[]): neotest-java.JunitResult[] }
--- @field remove_file fun(filepath: string): boolean, string?
--- @field tempname_fn fun(): string
--- @field output_writer? neotest-java.OutputWriter

--- @param deps neotest-java.ResultBuilderDeps
--- @return neotest-java.ResultBuilder
local ResultBuilder = function(deps)
	deps = deps or {}
	assert(deps.scan_dir, "scan_dir should not be nil")
	assert(deps.junit_result_reader, "junit_result_reader should not be nil")
	assert(deps.remove_file, "remove_file should not be nil")
	assert(deps.tempname_fn, "tempname_fn should not be nil")
	deps.output_writer = deps.output_writer or OutputWriter({ tempname_fn = deps.tempname_fn })

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
				return { [node.id] = to_neotest_result(JunitResult.ERROR(node.id, result.output), deps.output_writer) }
			end

			if spec.context.strategy == "dap" then
				spec.context.terminated_command_event.wait()
			end

			local report_files = find_report_files(spec.context.reports_dir)
			local testcases = deps.junit_result_reader.read_all(report_files)
			local groups = group_by_method_base(testcases)

			local results = {}

			for id, items in pairs(groups) do
				if #items == 1 then
					--- @type neotest-java.JunitResult
					local jres = items[1]

					results[id] = to_neotest_result(jres:result(), deps.output_writer)
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
						results[_id] = to_neotest_result(JunitResult.merge_results(items), deps.output_writer)
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
