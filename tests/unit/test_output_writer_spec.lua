---@diagnostic disable: undefined-field
local OutputWriter = require("neotest-java.util.output_writer")
local eq = require("tests.assertions").eq

--- Build an OutputWriter with fully stubbed I/O: no real tempfile, no real
--- disk write. Records every write via `writes` (keyed by filepath).
--- @param writes table<string, string>
--- @param tempname_fn? fun(): string
local function make_writer(writes, tempname_fn)
	local counter = 0
	tempname_fn = tempname_fn or function()
		counter = counter + 1
		return "/fake/tmp-" .. counter
	end

	local fake_file = {}
	local current_path
	fake_file.write = function(_, data)
		writes[current_path] = (writes[current_path] or "") .. data
	end
	fake_file.close = function() end

	return OutputWriter({
		tempname_fn = tempname_fn,
		open_file = function(filepath, _mode)
			current_path = filepath
			return fake_file
		end,
		run = function(fn)
			fn()
		end,
	})
end

describe("OutputWriter", function()
	it("returns nil and writes nothing when data is nil", function()
		local writes = {}
		local writer = make_writer(writes)

		local filepath = writer.write(nil)

		eq(nil, filepath)
		eq({}, writes)
	end)

	it("returns nil and writes nothing when data is an empty table", function()
		local writes = {}
		local writer = make_writer(writes)

		local filepath = writer.write({})

		eq(nil, filepath)
		eq({}, writes)
	end)

	it("writes a plain string to a new tempfile and returns its path", function()
		local writes = {}
		local writer = make_writer(writes, function()
			return "/fake/tmp-1"
		end)

		local filepath = writer.write("hello world")

		eq("/fake/tmp-1", filepath)
		eq("hello world", writes["/fake/tmp-1"])
	end)

	it("joins an array of lines with the visual separator", function()
		local writes = {}
		local writer = make_writer(writes, function()
			return "/fake/tmp-1"
		end)

		writer.write({ "line one", "line two" })

		assert(writes["/fake/tmp-1"]:find("line one", 1, true) ~= nil, "should contain first line")
		assert(writes["/fake/tmp-1"]:find("line two", 1, true) ~= nil, "should contain second line")
	end)

	it("flattens nested tables before writing", function()
		local writes = {}
		local writer = make_writer(writes, function()
			return "/fake/tmp-1"
		end)

		writer.write({ { "nested one" }, "top level" })

		assert(writes["/fake/tmp-1"]:find("nested one", 1, true) ~= nil, "should contain nested line")
		assert(writes["/fake/tmp-1"]:find("top level", 1, true) ~= nil, "should contain top-level line")
	end)

	it("uses a new tempname for every write call", function()
		local writes = {}
		local writer = make_writer(writes)

		local first = writer.write("a")
		local second = writer.write("b")

		assert(first ~= second, "each write should get its own tempfile")
		eq("a", writes[first])
		eq("b", writes[second])
	end)
end)
