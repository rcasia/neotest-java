---@diagnostic disable: undefined-field
local JunitResultReader = require("neotest-java.core.junit_result_reader")
local Path = require("neotest-java.model.path")
local eq = require("tests.assertions").eq

--- Build a stub XmlReader whose `parse` returns trees keyed by filepath.
--- Any filepath not present in `trees` returns an error.
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
local function make_reader(trees, warned)
	local xml_reader = stub_xml_reader(trees)
	warned = warned or {}
	local tempname_fn = function()
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

local P1 = "/fake/TEST-A.xml"
local P2 = "/fake/TEST-B.xml"

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
		local reader = make_reader({ [P1] = { tree = tree, error = nil } })

		-- when
		local results = reader.read_all({ Path(P1) })

		-- then — three JunitResult objects, each carrying the right testcase
		eq(3, #results)
		eq("com.example.ExampleTest#a()", results[1]:id())
		eq("com.example.ExampleTest#b()", results[2]:id())
		eq("com.example.ExampleTest#c()", results[3]:id())
		-- and they were constructed with the stubbed tempname
		eq("/tmp/test-output.txt", results[1].tempname)
		-- and the testcase payload is preserved
		eq("a()", results[1].testcase._attr.name)
	end)

	it("returns JunitResults for testcases across multiple files", function()
		-- given
		local tree1 = { _attr = {}, testsuite = { _attr = {}, testcase = { TC("a()") } } }
		local tree2 = { _attr = {}, testsuite = { _attr = {}, testcase = { TC("b()"), TC("c()") } } }
		local reader = make_reader({
			[P1] = { tree = tree1, error = nil },
			[P2] = { tree = tree2, error = nil },
		})

		-- when
		local results = reader.read_all({ Path(P1), Path(P2) })

		-- then
		eq(3, #results)
		eq("com.example.ExampleTest#a()", results[1]:id())
		eq("com.example.ExampleTest#b()", results[2]:id())
		eq("com.example.ExampleTest#c()", results[3]:id())
	end)

	it("contributes zero results when a file has no testsuite", function()
		-- given
		local tree = { _attr = {}, not_a_testsuite = "nope" }
		local reader = make_reader({ [P1] = { tree = tree, error = nil } })

		-- when
		local results = reader.read_all({ Path(P1) })

		-- then
		eq({}, results)
	end)

	it("contributes zero results when testsuite has no testcase", function()
		-- given
		local tree = { _attr = {}, testsuite = { _attr = {} } }
		local reader = make_reader({ [P1] = { tree = tree, error = nil } })

		-- when
		local results = reader.read_all({ Path(P1) })

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
		local reader = make_reader({ [P1] = { tree = tree, error = nil } })

		-- when
		local results = reader.read_all({ Path(P1) })

		-- then
		eq(1, #results)
		eq("com.example.ExampleTest#only()", results[1]:id())
	end)

	it("skips a file that produces a parse error and warns", function()
		-- given
		local warned = {}
		local reader = make_reader({ [P1] = { tree = nil, error = "malformed XML" } }, warned)

		-- when
		local results = reader.read_all({ Path(P1) })

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
			[P1] = { tree = nil, error = "boom" },
			[P2] = { tree = tree2, error = nil },
		}, warned)
		-- a second reader to also exercise a path that's not in the first reader's stubs
		local extra = "/fake/TEST-extra.xml"
		local reader2 = make_reader({
			[extra] = { tree = tree1, error = nil },
		}, warned)

		-- when
		local results = reader.read_all({ Path(P1), Path(P2) })
		local extra_results = reader2.read_all({ Path(extra) })

		-- then
		eq(1, #results)
		eq("com.example.ExampleTest#b()", results[1]:id())
		eq(1, #extra_results)
		eq("com.example.ExampleTest#a()", extra_results[1]:id())
		-- and the warn fired for the failing file (only once, only the failing read)
		eq(1, #warned)
	end)

	it("uses the injected tempname function for every constructed JunitResult", function()
		-- given
		local tree = {
			_attr = {},
			testsuite = { _attr = {}, testcase = { TC("a()"), TC("b()") } },
		}
		local calls = 0
		local xml_reader = stub_xml_reader({ [P1] = { tree = tree, error = nil } })
		local reader = JunitResultReader({
			xml_reader = xml_reader,
			tempname_fn = function()
				calls = calls + 1
				return "/tmp/call-" .. calls .. ".txt"
			end,
			log = { debug = function() end, warn = function() end },
		})

		-- when
		local results = reader.read_all({ Path(P1) })

		-- then
		eq(2, #results)
		eq(2, calls)
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
		reader.read_all({ Path(P1), Path(P2) })

		-- then
		eq(2, calls)
		eq(2, #warned)
	end)
end)
