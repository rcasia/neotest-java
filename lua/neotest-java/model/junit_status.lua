local junit_failure = require("neotest-java.model.junit_failure")

local FAILED = require("neotest.types").ResultStatus.failed
local PASSED = require("neotest.types").ResultStatus.passed

local M = {}

--- Derives the neotest result status (and normalized failures) from a
--- JUnit XML `testcase` node.
---
---@param testcase table
---@return neotest.ResultStatus
---@return table an array-like table containing tables of the form {failure_message: string, failure_output: string}
function M.derive(testcase)
	local failed = testcase.failure or testcase.error
	-- This is not parsed correctly by the library
	-- <failure message="expected: &lt;1> but was: &lt;2>" type="org.opentest4j.AssertionFailedError">
	-- it breaks in the first '>'
	-- so it does not detect message attribute sometimes
	if failed and not failed._attr then
		local failures = {}
		for i, fail in ipairs(failed) do
			if type(fail) ~= "table" then
				return FAILED, { junit_failure.from_node(failed) }
			end

			failures[i] = junit_failure.from_node(fail)
		end
		return FAILED, failures
	end
	if failed and failed._attr then
		return FAILED, { junit_failure.from_node(failed) }
	end
	return PASSED, {}
end

return M
