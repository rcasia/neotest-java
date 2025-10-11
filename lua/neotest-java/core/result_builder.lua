local xml = require("neotest.lib.xml")
local flat_map = require("neotest-java.util.flat_map")
local log = require("neotest-java.logger")
local lib = require("neotest.lib")
local JunitResult = require("neotest-java.types.junit_result")
local SKIPPED = JunitResult.SKIPPED

local REPORT_FILE_NAMES_PATTERN = "TEST-.+%.xml$"

-- Strip parameter list "(...)" and trailing "[index]" from a testcase name
-- e.g. "test(int, int)[1]" -> "test"
local function base_test_name(name)
	if not name or name == "" then
		return name
	end
	local s = name:gsub("%b()", "")
	s = s:gsub("%s+", "")
	s = s:gsub("%[%d+%]$", "")
	return s
end

-- Build group key "<classname>#<baseName>"
local function build_group_key(classname, testname)
	return tostring(classname) .. "#" .. tostring(base_test_name(testname))
end

-- Decide if a JUnit display name looks parameterized, e.g. "method(String)[1]" or "method(String)"
local function is_parameterized_display(display_name)
	if type(display_name) ~= "string" or display_name == "" then
		return false
	end
	if display_name:find("%b()") then
		return true
	end
	if display_name:find("%[%d+%]") then
		return true
	end
	return false
end

-- Prefix the parameterized display (from JUnit name) to short/error messages *only for parameterized cases*
local function add_param_prefix_to_messages_if_needed(result_tbl, display_name)
	if not result_tbl or not display_name or not is_parameterized_display(display_name) then
		return result_tbl
	end

	local function starts_with(s, prefix)
		return type(s) == "string" and s:find(prefix, 1, true) == 1
	end

	local prefix = display_name .. " -> "

	if result_tbl.short and not starts_with(result_tbl.short, display_name) then
		result_tbl.short = prefix .. result_tbl.short
	end

	if result_tbl.errors then
		for _, err in ipairs(result_tbl.errors) do
			if err.message and not starts_with(err.message, display_name) then
				err.message = prefix .. err.message
			end
		end
	end

	return result_tbl
end

local ResultBuilder = {}

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@param scan fun(dir: string, opts: table): string[]
---@param read_file fun(filepath: string): string
---@return table<string, neotest.Result>
function ResultBuilder.build_results(spec, result, tree, scan, read_file) -- luacheck: ignore 212 unused argument
	scan = scan or require("plenary.scandir").scan_dir
	read_file = read_file or require("neotest-java.util.read_file")

	-- if the test command failed, return an error
	if result.code ~= 0 and result.code ~= 1 then
		local node = tree:data()
		return { [node.id] = JunitResult.ERROR(node.id, result.output) }
	end

	-- wait for the debug test to finish
	if spec.context.strategy == "dap" then
		spec.context.terminated_command_event.wait()
	end

	---@type table<string, neotest.Result>
	local results = {}

	-- Read all report files
	local report_filepaths = scan(spec.context.reports_dir, {
		search_pattern = REPORT_FILE_NAMES_PATTERN,
	})
	log.debug("Found report files: ", report_filepaths)

	assert(#report_filepaths ~= 0, "no report file could be generated")

	local testcases_in_xml = flat_map(function(filepath)
		local ok, data = pcall(function()
			return read_file(filepath)
		end)
		if not ok then
			lib.notify("Error reading file: " .. filepath)
			return {}
		end

		local xml_data = xml.parse(data)
		local suite = xml_data.testsuite
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
	end, report_filepaths)

	-- Group JUnit results by "<classname>#<baseMethodName>"
	---@type table<string, neotest-java.JunitResult[]>
	local groups = {}

	for _, testcase in ipairs(testcases_in_xml) do
		local jres = JunitResult:new(testcase)
		local classname = jres:classname() -- FQCN (inner classes use $)
		local name = jres:name() -- may include params "(...)" and index "[n]"

		local gkey = build_group_key(classname, name)
		local bucket = groups[gkey]
		if not bucket then
			bucket = {}
			groups[gkey] = bucket
		end
		bucket[#bucket + 1] = jres
	end

	-- Walk requested nodes and build results
	for _, node in tree:iter() do
		if node.type ~= "test" then
			goto continue
		end

		-- node.id is "<fqClass>#<methodSignature or name>"
		local fq_class = tostring(node.id):match("^(.-)#") or ""
		local method_base = node.name -- plain method identifier

		local key = fq_class .. "#" .. method_base
		local bucket = groups[key]

		if bucket and #bucket > 0 then
			if #bucket == 1 then
				-- Single execution (plain test or parameterized with a single case like @EmptySource)
				local jres = bucket[1]
				local res = jres:result()
				res = add_param_prefix_to_messages_if_needed(res, jres:name())
				results[node.id] = res
			else
				-- Multiple executions -> merged unified result
				-- We keep the merge behavior identical (operates on JunitResult list).
				-- (If needed later, we can enhance JunitResult.merge_results to carry prefixed messages.)
				results[node.id] = JunitResult.merge_results(bucket)
			end
		else
			-- Not found in reports -> SKIPPED
			results[node.id] = SKIPPED(node.id)
		end

		::continue::
	end

	return results
end

return ResultBuilder
