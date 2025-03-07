local nio = require("nio")

local FAILED = require("neotest.types").ResultStatus.failed
local PASSED = require("neotest.types").ResultStatus.passed
local SKIPPED = require("neotest.types").ResultStatus.skipped

local LINE_SEPARATOR = "=================================\n"
local NEW_LINE = "\n"

---@param data string | string[] | table
---@return string | nil filepath
local function create_file_with_content(data)
	if not data then
		return nil
	end

	if type(data) == "table" then
		if #data == 0 then
			return nil
		end
		data = vim.iter(vim.tbl_values(data)):flatten(math.huge):totable()
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

---@class neotest-java.JunitResult
---@field testcase table
local JunitResult = {}

---@return neotest.Result
function JunitResult.SKIPPED(id)
	return {
		status = SKIPPED,
		output = create_file_with_content({ id, "This test was not executed." }),
	}
end

---@return neotest.Result
function JunitResult.ERROR(id, output)
	return {
		status = "failed",
		output = output or create_file_with_content({ id, "This test execution had an unexpected error." }),
	}
end

function JunitResult:new(testcase)
	self.__index = self
	return setmetatable({ testcase = testcase }, self)
end

function JunitResult:id()
	return self:name()
end

---@return string
function JunitResult:name()
	return self.testcase._attr.name
end

---@return string
function JunitResult:classname()
	return self.testcase._attr.classname
end

---@return neotest.ResultStatus
---@return string | nil failure_message a short output
---@return string | nil failure_output a more detailed output
function JunitResult:status()
	local failed = self.testcase.failure or self.testcase.error
	-- This is not parsed correctly by the library
	-- <failure message="expected: &lt;1> but was: &lt;2>" type="org.opentest4j.AssertionFailedError">
	-- it breaks in the first '>'
	-- so it does not detect message attribute sometimes
	if failed and not failed._attr then
		return FAILED, failed[1], failed[2]
	end
	if failed and failed._attr then
		return FAILED, failed._attr.message, failed[1]
	end
	return PASSED
end

---@param with_name_prefix? boolean
---@return neotest.Error[] | nil
function JunitResult:errors(with_name_prefix)
	with_name_prefix = with_name_prefix or false
	local status, failure_message, failure_output = self:status()
	local filename = string.match(self:classname(), "[%.]?([%a%$_][%a%d%$_]+)$") .. ".java"
	local line_searchpattern = string.gsub(filename, "%.", "%%.") .. ":(%d+)%)"

	local line
	if failure_output then
		line = string.match(failure_output, line_searchpattern)
		-- NOTE: errors array is expecting lines properties to be 0 index based
		line = line and line - 1 or nil
	end

	if status == PASSED then
		return nil
	end
	if with_name_prefix then
		failure_message = self:name() .. " -> " .. failure_message
	end
	return { { message = failure_message, line = line } }
end

---@return string[]
function JunitResult:output()
	local system_out = self.testcase["system-out"] or {}
	if type(system_out) == "string" then
		system_out = { system_out }
	end

	local status, _, failure_output = self:status()
	if status == FAILED then
		system_out[#system_out + 1] = failure_output
	else -- PASSED
		system_out[#system_out + 1] = "Test passed" .. NEW_LINE
	end

	return system_out
end

--- Convert neotest-java.JunitResult to neotest.Result
--- Each time this function is called, it will create a temporary file with the output content
---@return neotest.Result
function JunitResult:result()
	local status, failure_message = self:status()
	return {
		status = status,
		short = failure_message,
		errors = self:errors(),
		output = create_file_with_content(self:output()),
	}
end

---@param results neotest-java.JunitResult[]
---@return neotest.Result
function JunitResult.merge_results(results)
	table.sort(results, function(a, b)
		return a:name() < b:name()
	end)

	local status = vim.iter(results):any(function(result)
		return result:status() == FAILED
	end) and FAILED or PASSED

	local output = vim
		.iter(results)
		:map(function(result)
			return result:output()
		end)
		:flatten(math.huge)
		:totable()

	if status == PASSED then
		return { status = status, output = create_file_with_content(output) }
	end

	local errors = vim
		.iter(results)
		:map(function(result)
			return result:errors(true)
		end)
		:flatten()
		:totable()

	local short = vim
		.iter(results)
		:filter(function(result)
			return result:status() == FAILED
		end)
		:map(function(result)
			return result:errors(), result:name()
		end)
		:map(function(error, name)
			return name .. " -> " .. error[1].message
		end)
		:fold(nil, function(a, b)
			if not a then
				return b
			end
			return a .. NEW_LINE .. b
		end)

	return { status = status, errors = errors, short = short, output = create_file_with_content(output) }
end

return JunitResult
