local xml = require("neotest.lib.xml")
local flat_map = require("neotest-java.util.flat_map")
local log = require("neotest-java.logger")
local lib = require("neotest.lib")
local JunitResult = require("neotest-java.types.junit_result")

local SKIPPED = JunitResult.SKIPPED
local REPORT_FILE_NAMES_PATTERN = "TEST-.+%.xml$"

-- -----------------------------------------------------------------------------
-- Name normalization and grouping
-- -----------------------------------------------------------------------------

local function base_test_name(name)
	if type(name) ~= "string" or name == "" then
		return name
	end
	local s = name:gsub("%b()", "") -- drop "(...)"
	s = s:gsub("%s+", "") -- drop whitespace
	s = s:gsub("%[%d+%]$", "") -- drop trailing "[digits]"
	return s
end

local function build_group_key(classname, junit_display_name)
	return tostring(classname) .. "#" .. tostring(base_test_name(junit_display_name))
end

local function is_parameterized_display(display_name)
	if type(display_name) ~= "string" or display_name == "" then
		return false
	end
	return display_name:find("%b()") or display_name:find("%[%d+%]") or false
end

local function maybe_prefix_messages(result_tbl, display_name)
	if not (result_tbl and is_parameterized_display(display_name)) then
		return result_tbl
	end
	local prefix = display_name .. " -> "
	local function starts_with(s, pre)
		return type(s) == "string" and s:find(pre, 1, true) == 1
	end
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

-- -----------------------------------------------------------------------------
-- XML loading
-- -----------------------------------------------------------------------------
--
--

---@generic T
---@param v T
local function Ok(v)
	return {
		tag = "result",
		ok = true,
		value = v,
		map = function(fn)
			local res = fn(v)
			if res.tag == "result" then
				return res
			else
				return Ok(res)
			end
		end,
	}
end
---@param e any
local function Err(e)
	return {
		tag = "result",
		ok = false,
		error = e,
		map = function()
			return Err(e)
		end,
	}
end

local function pipe(...)
	local fns = { ... }

	return function(x)
		local result = x
		for i = 1, #fns do
			result = fns[i](result)
		end
		return result
	end
end

local function map(fn)
	return function(x)
		return fn(x)
	end
end

local function debug(x)
	print(vim.inspect(x))
	return x
end

local function safe_fn_call(fn)
	return function(...)
		local ok, res = pcall(fn, ...)
		if ok then
			return Ok(res)
		else
			return Err(res)
		end
	end
end

local prop = function(key)
	return function(tbl)
		return tbl[key]
	end
end

local function load_all_testcases(reports_dir, scan, read_file)
	local read_files = pipe(
		--
		function(dir)
			return scan(dir, { search_pattern = REPORT_FILE_NAMES_PATTERN })
		end,

		map(function(filepaths)
			return vim.iter(filepaths)
				:map(function(filepath)
					return safe_fn_call(read_file)(filepath)
				end)
				:totable()
		end)
	)

	local get_successful_reads = pipe(
		--
		map(function(reads_results)
			return vim.iter(reads_results)
				:filter(function(r)
					return r.ok
				end)
				:map(function(r)
					return r.value
				end)
				:totable()
		end)
	)

	local process_xml = pipe(
		map(xml.parse),

		prop("testsuite"),
		prop("testcase"),
		map(function(tcs)
			if not vim.isarray(tcs) then
				return { tcs }
			end
			return tcs
		end)
	)

	local read_xml_strings = pipe(
		--
		read_files,
		get_successful_reads
	)

	local res = read_xml_strings(reports_dir)

	return vim.iter(res):map(process_xml):flatten():totable()
end

local function group_by_method_base(testcases)
	local groups = {}
	for _, tc in ipairs(testcases) do
		local jres = JunitResult:new(tc)
		local key = build_group_key(jres:classname(), jres:name())

		groups[key] = groups[key] or {}
		table.insert(groups[key], jres)
	end
	return groups
end

-- -----------------------------------------------------------------------------
-- Public API
-- -----------------------------------------------------------------------------

local ResultBuilder = {}

function ResultBuilder.build_results(spec, result, tree, scan, read_file)
	scan = scan or require("plenary.scandir").scan_dir
	read_file = read_file or require("neotest-java.util.read_file")

	if result.code ~= 0 and result.code ~= 1 then
		local node = tree:data()
		return { [node.id] = JunitResult.ERROR(node.id, result.output) }
	end

	if spec.context.strategy == "dap" then
		spec.context.terminated_command_event.wait()
	end

	local testcases = load_all_testcases(spec.context.reports_dir, scan, read_file)
	local groups = group_by_method_base(testcases)
	local results = {}

	for _, node in tree:iter() do
		if node.type ~= "test" then
			goto continue
		end

		local fq_class = tostring(node.id):match("^(.-)#") or ""
		local key = fq_class .. "#" .. node.name
		local bucket = groups[key]

		if bucket and #bucket > 0 then
			if #bucket == 1 then
				local jres = bucket[1]
				results[node.id] = maybe_prefix_messages(jres:result(), jres:name())
			else
				results[node.id] = JunitResult.merge_results(bucket)
			end
		else
			results[node.id] = SKIPPED(node.id)
		end

		::continue::
	end

	return results
end

return ResultBuilder
