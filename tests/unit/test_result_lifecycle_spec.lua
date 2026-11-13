local ResultBuilder = require("neotest-java.core.result_builder")
local JunitResult = require("neotest-java.model.junit_result")
local Path = require("neotest-java.model.path")
local Tree = require("neotest.types").Tree
local eq = require("tests.assertions").eq

local id = "example.Test#selected()"
local other = "example.Test#missing()"
local tree = Tree.from_list({
	{ id = "file", name = "file", path = "Test.java", type = "file" },
	{ id = id, name = "selected", path = "Test.java", type = "test" },
	{ id = other, name = "missing", path = "Test.java", type = "test" },
}, function(pos)
	return pos.id
end)

local function setup(testcases, process)
	local cleaned, scans = 0, 0
	local spec = {
		context = {
			reports_dir = Path("invocation-owned"),
			process = process,
			cleanup_reports = function()
				cleaned = cleaned + 1
			end,
		},
	}
	local builder = ResultBuilder({
		scan_dir = function()
			scans = scans + 1
			return {}
		end,
		junit_result_reader = {
			read_all = function()
				return testcases
			end,
		},
		remove_file = function()
			return true
		end,
		tempname_fn = function()
			return vim.fn.tempname()
		end,
	})
	return function(result)
		return builder.build_results(spec, result or { code = 0, output = "process.log" }, tree)
	end, function()
		return cleaned, scans
	end
end

describe("Result lifecycle", function()
	it("fails every selected test when reports are absent or empty", function()
		local run, inspect = setup({})
		local results = run()
		for _, key in ipairs({ id, other }) do
			eq("failed", results[key].status)
			assert(results[key].short:find(key, 1, true))
		end
		eq(1, inspect())
	end)

	it("preserves a reported pass but fails an unreported selected test", function()
		local run = setup({ JunitResult:new({ _attr = { name = "selected()", classname = "example.Test" } }) })
		local results = run()
		eq("passed", results[id].status)
		eq("failed", results[other].status)
	end)

	for _, reason in ipairs({ "cancelled", "attach failed", "exit timeout" }) do
		it("never trusts reports after " .. reason, function()
			local stopped = 0
			local run, inspect = setup({}, {
				stop = function()
					stopped = stopped + 1
				end,
				wait_exit = function()
					return { exited = true, code = 0 }
				end,
			})
			local results = run({ code = 1, error = reason, output = "process.log" })
			eq(1, stopped)
			local cleaned, scans = inspect()
			eq(1, cleaned)
			eq(0, scans)
			for _, key in ipairs({ id, other }) do
				eq("failed", results[key].status)
				eq(reason, results[key].short)
			end
		end)
	end

	it("uses the owned JVM status even when the debugger says success", function()
		local run = setup({}, {
			wait_exit = function()
				return { exited = true, code = 17, stderr = "JVM failed" }
			end,
		})
		local results = run()
		eq("failed", results[id].status)
		assert(results[id].short:find("17", 1, true))
	end)
end)
