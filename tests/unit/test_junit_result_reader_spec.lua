---@diagnostic disable: undefined-field
local JunitResultReader = require("neotest-java.core.junit_result_reader")
local Path = require("neotest-java.model.path")
local eq = require("tests.assertions").eq

-- Use Path objects throughout so the test is cross-platform. The reader
-- uses filepath as the stub lookup key directly, and Path's __eq
-- compares by stringified path, so a Path constructed on Windows
-- (with backslashes) matches the same Path here.
-- Use Path objects for cross-platform correctness; the stub keys use
-- the stringified form.
local P1 = Path("/fake/TEST-A.xml")
local P2 = Path("/fake/TEST-B.xml")
local K1 = tostring(P1)
local K2 = tostring(P2)

--- Build a stub XmlReader whose `parse` returns trees keyed by the stringified
--- filepath. Using tostring as the key (rather than the Path object itself)
--- sidesteps Lua's raw-equality table indexing — two distinct Path objects
--- with the same path would not match as keys, even though `__eq` is defined.
--- @param trees table<string, { tree: table, error: string | nil }>
local function stub_xml_reader(trees)
	local function parse(filepath)
		local key = tostring(filepath)
		if trees[key] then
			return trees[key]
		end
		return { tree = nil, error = "no stub for " .. key }
	end
	return { parse = parse }
end

--- Build a JunitResultReader with the given trees and a known tempname.
--- Records warn calls in `warned`.
local function make_reader(trees, warned, tempname_fn)
	local xml_reader = stub_xml_reader(trees)
	warned = warned or {}
	tempname_fn = tempname_fn or function()
		return "/tmp/test-output.txt"
	end
	local log = {
		debug = function() end,
		warn = function(...)
			table.insert(warned, { ... })
		end,
	}
	return JunitResultReader({
		xml_reader = xml_reader,
		tempname_fn = tempname_fn,
		log = log,
	})
end

local TC = function(name, classname)
	return {
		_attr = { name = name, classname = classname or "com.example.ExampleTest" },
	}
end

describe("JunitResultReader", function()
	it("returns an empty array when paths is empty", function()
		-- given
		local reader = make_reader({})

		-- when
		local results = reader.read_all({})

		-- then
		eq({}, results)
	end)

	it("returns one JunitResult per testcase in a single file", function()
		-- given
		local tree = {
			_attr = {},
			testsuite = {
				_attr = {},
				testcase = { TC("a()"), TC("b()"), TC("c()") },
			},
		}
		local reader = make_reader({ [K1] = { tree = tree, error = nil } })

		-- when
		local results = reader.read_all({ P1 })

		-- then — three JunitResult objects, each carrying the right testcase
		eq(3, #results)
		eq("com.example.ExampleTest#a()", results[1]:id())
		eq("com.example.ExampleTest#b()", results[2]:id())
		eq("com.example.ExampleTest#c()", results[3]:id())
		-- and each was constructed with the injected tempname function
		for _, jres in ipairs(results) do
			eq("function", type(jres.tempname))
		end
		-- and the testcase payload is preserved
		eq("a()", results[1].testcase._attr.name)
	end)

	it("returns JunitResults for testcases across multiple files", function()
		-- given
		local tree1 = { _attr = {}, testsuite = { _attr = {}, testcase = { TC("a()") } } }
		local tree2 = { _attr = {}, testsuite = { _attr = {}, testcase = { TC("b()"), TC("c()") } } }
		local reader = make_reader({
			[K1] = { tree = tree1, error = nil },
			[K2] = { tree = tree2, error = nil },
		})

		-- when
		local results = reader.read_all({ P1, P2 })

		-- then
		eq(3, #results)
		eq("com.example.ExampleTest#a()", results[1]:id())
		eq("com.example.ExampleTest#b()", results[2]:id())
		eq("com.example.ExampleTest#c()", results[3]:id())
	end)

	it("contributes zero results when a file has no testsuite", function()
		-- given
		local tree = { _attr = {}, not_a_testsuite = "nope" }
		local reader = make_reader({ [K1] = { tree = tree, error = nil } })

		-- when
		local results = reader.read_all({ P1 })

		-- then
		eq({}, results)
	end)

	it("contributes zero results when testsuite has no testcase", function()
		-- given
		local tree = { _attr = {}, testsuite = { _attr = {} } }
		local reader = make_reader({ [K1] = { tree = tree, error = nil } })

		-- when
		local results = reader.read_all({ P1 })

		-- then
		eq({}, results)
	end)

	it("treats a single testcase table the same as an array of one", function()
		-- given — xml2lua quirk: a single testcase comes back as a table, not array
		local tree = {
			_attr = {},
			testsuite = {
				_attr = {},
				testcase = TC("only()"),
			},
		}
		local reader = make_reader({ [K1] = { tree = tree, error = nil } })

		-- when
		local results = reader.read_all({ P1 })

		-- then
		eq(1, #results)
		eq("com.example.ExampleTest#only()", results[1]:id())
	end)

	it("skips a file that produces a parse error and warns", function()
		-- given
		local warned = {}
		local reader = make_reader({ [K1] = { tree = nil, error = "malformed XML" } }, warned)

		-- when
		local results = reader.read_all({ P1 })

		-- then
		eq({}, results)
		eq(1, #warned)
	end)

	it("skips the failing file but processes the rest", function()
		-- given
		local tree1 = { _attr = {}, testsuite = { _attr = {}, testcase = { TC("a()") } } }
		local tree2 = { _attr = {}, testsuite = { _attr = {}, testcase = { TC("b()") } } }
		local warned = {}
		local reader = make_reader({
			[K1] = { tree = nil, error = "boom" },
			[K2] = { tree = tree2, error = nil },
		}, warned)
		-- a second reader to also exercise a path that's not in the first reader's stubs
		local extra = Path("/fake/TEST-extra.xml")
		local extra_key = tostring(extra)
		local reader2 = make_reader({
			[extra_key] = { tree = tree1, error = nil },
		}, warned)

		-- when
		local results = reader.read_all({ P1, P2 })
		local extra_results = reader2.read_all({ extra })

		-- then
		eq(1, #results)
		eq("com.example.ExampleTest#b()", results[1]:id())
		eq(1, #extra_results)
		eq("com.example.ExampleTest#a()", extra_results[1]:id())
		-- and the warn fired for the failing file (only once, only the failing read)
		eq(1, #warned)
	end)

	it("stores the injected tempname function on every JunitResult (no call yet)", function()
		-- given
		local tree = {
			_attr = {},
			testsuite = { _attr = {}, testcase = { TC("a()"), TC("b()") } },
		}
		local xml_reader = stub_xml_reader({ [K1] = { tree = tree, error = nil } })
		local injected = function()
			return "/tmp/should-not-be-called.txt"
		end
		local reader = JunitResultReader({
			xml_reader = xml_reader,
			tempname_fn = injected,
			log = { debug = function() end, warn = function() end },
		})

		-- when
		local results = reader.read_all({ P1 })

		-- then — every JunitResult holds a reference to the injected function
		eq(2, #results)
		eq(injected, results[1].tempname)
		eq(injected, results[2].tempname)
	end)

	it("uses the injected xml_reader — no real XmlReader construction", function()
		-- given — a reader with an xml_reader that records its calls
		local calls = 0
		local xml_reader = {
			parse = function(_)
				calls = calls + 1
				return { tree = nil, error = "forced" }
			end,
		}
		local warned = {}
		local reader = JunitResultReader({
			xml_reader = xml_reader,
			tempname_fn = function()
				return "/tmp/x"
			end,
			log = {
				debug = function() end,
				warn = function(...)
					table.insert(warned, { ... })
				end,
			},
		})

		-- when
		reader.read_all({ P1, P2 })

		-- then
		eq(2, calls)
		eq(2, #warned)
	end)
end)
