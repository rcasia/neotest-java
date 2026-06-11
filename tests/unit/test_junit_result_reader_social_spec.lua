---@diagnostic disable: undefined-field
local JunitResultReader = require("neotest-java.core.junit_result_reader")
local Path = require("neotest-java.model.path")
local eq = require("tests.assertions").eq

-- A real JunitResultReader against a stub XmlReader that returns tree shapes
-- that mirror what the real xml2lua parser produces. This is the "social"
-- layer — we exercise the JUnit walk against realistic tree shapes without
-- touching XML strings.

-- Use Path objects throughout so the test is cross-platform.
local P1 = Path("/fake/TEST-A.xml")
local P2 = Path("/fake/TEST-B.xml")
local K1 = tostring(P1)
local K2 = tostring(P2)

--- Build a reader with a stub xml_reader keyed by stringified filepath, plus
--- a known tempname. Records warns in `warned` if provided.
local function reader_with(trees, warned)
	local function parse(filepath)
		local key = tostring(filepath)
		if trees[key] then
			return trees[key]
		end
		return { tree = nil, error = "no stub for " .. key }
	end
	return JunitResultReader({
		xml_reader = { parse = parse },
		tempname_fn = function()
			return "/tmp/social.txt"
		end,
		log = {
			debug = function() end,
			warn = function(...)
				if warned then
					table.insert(warned, { ... })
				end
			end,
		},
	})
end

--- The xml2lua shape for a testcase with a failure — every field in `_attr`
--- plus a `failure` child element. The parser wraps these in their own tables.
local function failing_testcase(name, classname, message, type_attr, body)
	return {
		_attr = { name = name, classname = classname or "com.example.ExampleTest", time = "0.001" },
		failure = {
			_attr = { message = message, type = type_attr or "java.lang.AssertionError" },
			body,
		},
	}
end

local function passing_testcase(name, classname)
	return {
		_attr = { name = name, classname = classname or "com.example.ExampleTest", time = "0" },
	}
end

describe("JunitResultReader (social)", function()
	it("walks a typical failing-tree shape produced by xml2lua", function()
		-- given
		local tree = {
			_attr = {},
			testsuite = {
				_attr = {},
				testcase = failing_testcase(
					"firstTestMethod()",
					"com.example.ExampleTest",
					"expected: <true> but was: <false>",
					"org.opentest4j.AssertionFailedError",
					"OUTPUT TEXT"
				),
			},
		}
		local reader = reader_with({ [K1] = { tree = tree, error = nil } })

		-- when
		local results = reader.read_all({ P1 })

		-- then
		eq(1, #results)
		eq("com.example.ExampleTest#firstTestMethod()", results[1]:id())
		-- JunitResult:status() should detect the failure
		local status, failures = results[1]:status()
		eq("failed", status)
		eq(1, #failures)
		eq("expected: <true> but was: <false>", failures[1].failure_message)
	end)

	it("walks a testsuite with multiple testcases (passed + failed)", function()
		-- given
		local tree = {
			_attr = {},
			testsuite = {
				_attr = {},
				testcase = {
					passing_testcase("a()"),
					failing_testcase("b()", "com.example.ExampleTest", "boom", "AssertionError", "trace"),
					passing_testcase("c()"),
				},
			},
		}
		local reader = reader_with({ [K1] = { tree = tree, error = nil } })

		-- when
		local results = reader.read_all({ P1 })

		-- then
		eq(3, #results)
		eq("passed", (results[1]:status()))
		eq("failed", (results[2]:status()))
		eq("passed", (results[3]:status()))
	end)

	it("walks a testsuite with sibling system-out and system-err elements", function()
		-- given — the real parser keeps these as siblings of testcase
		local tree = {
			_attr = {},
			testsuite = {
				_attr = {},
				testcase = {
					{
						_attr = { name = "noisy()", classname = "com.example.NoisyTest" },
						system_out = { "captured stdout" },
						system_err = { "captured stderr" },
					},
				},
			},
		}
		local reader = reader_with({ [K1] = { tree = tree, error = nil } })

		-- when
		local results = reader.read_all({ P1 })

		-- then
		eq(1, #results)
		-- and the system-out / system-err are preserved on the testcase
		eq("captured stdout", results[1].testcase.system_out[1])
		eq("captured stderr", results[1].testcase.system_err[1])
	end)

	it("walks a nested-failure shape (failure wrapping multiple children)", function()
		-- given — the prior bug fix (#296) was about xml2lua returning failure as
		-- an array of children when the message contained '>'. This shape exercises it.
		local tree = {
			_attr = {},
			testsuite = {
				_attr = {},
				testcase = {
					{
						_attr = { name = "gt()", classname = "com.example.GtTest" },
						failure = {
							_attr = { message = "expected: <1> but was: <2>", type = "AssertionFailedError" },
							{ "fragment one" },
							{ "fragment two" },
						},
					},
				},
			},
		}
		local reader = reader_with({ [K1] = { tree = tree, error = nil } })

		-- when
		local results = reader.read_all({ P1 })

		-- then — the result_builder groups these by id; here we just want the
		-- JunitResult to be constructed without crashing, with a failed status
		eq(1, #results)
		local status = (results[1]:status())
		eq("failed", status)
	end)

	it("walks a tree across two files independently", function()
		-- given
		local tree_a = {
			_attr = {},
			testsuite = { _attr = {}, testcase = { passing_testcase("a1()", "com.example.A") } },
		}
		local tree_b = {
			_attr = {},
			testsuite = {
				_attr = {},
				testcase = { passing_testcase("b1()", "com.example.B"), passing_testcase("b2()", "com.example.B") },
			},
		}
		local reader = reader_with({
			[K1] = { tree = tree_a, error = nil },
			[K2] = { tree = tree_b, error = nil },
		})

		-- when
		local results = reader.read_all({ P1, P2 })

		-- then
		eq(3, #results)
		eq("com.example.A#a1()", results[1]:id())
		eq("com.example.B#b1()", results[2]:id())
		eq("com.example.B#b2()", results[3]:id())
	end)

	it("skips a failing file but processes a succeeding sibling in the same call", function()
		-- given
		local tree = {
			_attr = {},
			testsuite = { _attr = {}, testcase = { passing_testcase("only()") } },
		}
		local warned = {}
		local reader = reader_with({
			[K1] = { tree = nil, error = "parse failed" },
			[K2] = { tree = tree, error = nil },
		}, warned)

		-- when
		local results = reader.read_all({ P1, P2 })

		-- then
		eq(1, #results)
		eq("com.example.ExampleTest#only()", results[1]:id())
		eq(1, #warned)
	end)
end)
