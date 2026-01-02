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
---@return table an array-like table containing tables of the form {failure_message: string, failure_output: string}
function JunitResult:status()
	local failed = self.testcase.failure or self.testcase.error
	-- This is not parsed correctly by the library
	-- <failure message="expected: &lt;1> but was: &lt;2>" type="org.opentest4j.AssertionFailedError">
	-- it breaks in the first '>'
	-- so it does not detect message attribute sometimes
	if failed and not failed._attr then
		local failures = {}
		for i, fail in ipairs(failed) do
			failures[i] = {
				failure_message = fail._attr.message or fail._attr.type or "<unknown failure>",
				failure_output = fail[1],
			}
		end
		return FAILED, failures
	end
	if failed and failed._attr then
		local fail = {
			failure_message = failed._attr.message or failed._attr.type or "<unknown failure>",
			failure_output = failed[1],
		}
		return FAILED, { fail }
	end
	return PASSED
end

---@param with_name_prefix? boolean
---@return neotest.Error[] | nil
function JunitResult:errors(with_name_prefix)
	with_name_prefix = with_name_prefix or false
	local status, failures = self:status()
	if status == PASSED then
		return nil
	end

	local filename = string.match(self:classname(), "[%.]?([%a%$_][%a%d%$_]+)$") .. ".java"
	local line_searchpattern = string.gsub(filename, "%.", "%%.") .. ":(%d+)%)"
	local errors = {}

	for i, failure in ipairs(failures) do
		local line
		if failure.failure_output then
			line = string.match(failure.failure_output, line_searchpattern)
			-- NOTE: errors array is expecting lines properties to be 0 index based
			line = line and line - 1 or nil
		end

		local failure_message = failure.failure_message
		if with_name_prefix then
			failure_message = self:name() .. " -> " .. failure_message
		end

		errors[i] = { message = failure_message, line = line }
	end

	return errors
end

---@return string[]
function JunitResult:output()
	local system_out = self.testcase["system-out"] or {}
	if type(system_out) == "string" then
		system_out = { system_out }
	end

	local status, failures = self:status()
	if status == FAILED then
		for _, failure in ipairs(failures) do
			system_out[#system_out + 1] = failure.failure_output
			system_out[#system_out + 1] = NEW_LINE
		end
	else -- PASSED
		system_out[#system_out + 1] = "Test passed" .. NEW_LINE
	end

	return system_out
end

--- Convert neotest-java.JunitResult to neotest.Result
--- Each time this function is called, it will create a temporary file with the output content
---@return neotest.Result
function JunitResult:result()
	local status, failures = self:status()
	local failure_message = ""
	if failures then
		for i, failure in ipairs(failures) do
			failure_message = failure_message .. failure.failure_message
			if i < #failures then
				failure_message = failure_message .. NEW_LINE
			end
		end
	end

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

	local output = vim.iter(results)
		:map(function(result)
			return result:output()
		end)
		:flatten(math.huge)
		:totable()

	if status == PASSED then
		return { status = status, output = create_file_with_content(output) }
	end

	local errors = vim.iter(results)
		:map(function(result)
			return result:errors(true)
		end)
		:flatten()
		:totable()

	local short = vim.iter(results)
		:filter(function(result)
			return result:status() == FAILED
		end)
		:map(function(result)
			return result:errors(), result:name()
		end)
		:map(function(error, name)
			if #error == 1 then
				return name .. " -> " .. error[1].message
			end

			local errs = name .. " -> {" .. NEW_LINE
			for i, err in ipairs(error) do
				errs = errs .. err.message
				if i < #error then
					errs = errs .. NEW_LINE
				end
			end
			return errs .. NEW_LINE .. "}"
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
