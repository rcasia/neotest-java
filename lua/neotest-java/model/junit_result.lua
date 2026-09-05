local junit_failure = require("neotest-java.model.junit_failure")
local junit_status = require("neotest-java.model.junit_status")

local FAILED = require("neotest.types").ResultStatus.failed
local PASSED = require("neotest.types").ResultStatus.passed
local SKIPPED = require("neotest.types").ResultStatus.skipped

local NEW_LINE = "\n"

--- @class neotest-java.JunitResult
--- @field testcase table
local JunitResult = {}

--- @class neotest-java.JunitResultData
--- @field status neotest.ResultStatus
--- @field output_lines string[]
--- @field errors neotest.Error[] | nil
--- @field short string | nil

---@param id string
---@return neotest-java.JunitResultData
function JunitResult.SKIPPED(id)
	return {
		status = SKIPPED,
		output_lines = { id, "This test was not executed." },
	}
end

---@param id string
---@param output? string
---@return neotest-java.JunitResultData
function JunitResult.ERROR(id, output)
	return {
		status = "failed",
		output_lines = output or { id, "This test execution had an unexpected error." },
	}
end

---@param testcase table
function JunitResult:new(testcase)
	self.__index = self
	return setmetatable({ testcase = testcase }, self)
end

function JunitResult:id()
	local id = self:classname() .. "#" .. self:name()

	-- exclude iterations from parameterized tests
	return id:gsub("%s*%[%d+%]$", "")
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
	return junit_status.derive(self.testcase)
end

---@param with_name_prefix? boolean
---@return neotest.Error[] | nil
function JunitResult:errors(with_name_prefix)
	with_name_prefix = with_name_prefix or false
	local status, failures = self:status()
	if status == PASSED then
		return nil
	end

	local errors = {}

	for i, failure in ipairs(failures) do
		local line = junit_failure.line_number(failure.failure_output, self:classname())

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
	local output_lines = {}

	local system_out = self.testcase["system-out"]
	if system_out then
		if type(system_out) == "string" then
			output_lines[#output_lines + 1] = system_out
		else
			for _, out in ipairs(system_out) do
				output_lines[#output_lines + 1] = out
			end
		end
	end

	local system_err = self.testcase["system-err"]
	if system_err then
		if #output_lines > 0 then
			output_lines[#output_lines + 1] = NEW_LINE
		end
		output_lines[#output_lines + 1] = "---- SYSTEM ERROR ----\n"

		if type(system_err) == "string" then
			output_lines[#output_lines + 1] = system_err
		else
			for _, err in ipairs(system_err) do
				output_lines[#output_lines + 1] = err
			end
		end
		output_lines[#output_lines + 1] = NEW_LINE
	end

	local status, failures = self:status()
	if status == FAILED then
		for _, failure in ipairs(failures) do
			output_lines[#output_lines + 1] = failure.failure_output
			output_lines[#output_lines + 1] = NEW_LINE
		end
	else -- PASSED
		output_lines[#output_lines + 1] = "Test passed" .. NEW_LINE
	end

	return output_lines
end

---@return string | nil
local function short_failure_message(status, failures)
	if status == PASSED then
		return nil
	end

	local message = ""
	for i, failure in ipairs(failures) do
		message = message .. failure.failure_message
		if i < #failures then
			message = message .. NEW_LINE
		end
	end
	return message
end

--- Converts this JunitResult into plain result data: status, output lines,
--- errors and a short failure summary. Callers (e.g. `result_builder`) are
--- responsible for turning `output_lines` into a `neotest.Result.output`
--- filepath via an `neotest-java.OutputWriter` — this method does no I/O.
---@return neotest-java.JunitResultData
function JunitResult:result()
	local status, failures = self:status()

	return {
		status = status,
		output_lines = self:output(),
		errors = self:errors(),
		short = short_failure_message(status, failures),
	}
end

---@param results neotest-java.JunitResult[]
---@return neotest-java.JunitResultData
function JunitResult.merge_results(results)
	table.sort(results, function(a, b)
		return a:name() < b:name()
	end)

	local status = vim.iter(results):any(function(result)
		return result:status() == FAILED
	end) and FAILED or PASSED

	local output_lines = vim.iter(results)
		:map(function(result)
			return result:output()
		end)
		:flatten(math.huge)
		:totable()

	local errors, short
	if status == FAILED then
		errors = vim.iter(results)
			:map(function(result)
				return result:errors(true)
			end)
			:flatten()
			:totable()

		short = vim.iter(results)
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
	end

	return { status = status, output_lines = output_lines, errors = errors, short = short }
end

return JunitResult
