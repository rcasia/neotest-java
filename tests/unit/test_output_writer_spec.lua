---@diagnostic disable: undefined-field
local OutputWriter = require("neotest-java.util.output_writer")
local eq = require("tests.assertions").eq

-- Mirrors the private LINE_SEPARATOR constant in
-- neotest-java.util.output_writer — kept in sync manually since the
-- constant isn't exported (it's an internal formatting detail).
local LINE_SEPARATOR = "=================================\n"

--- Build an OutputWriter whose I/O is entirely stubbed: `open_file` and
--- `run` never touch a real file or the async scheduler. Returns the
--- writer plus a `written` list you can inspect: each entry is
--- `{ filepath = string, data = string }`, one per `write()` call.
--- @param opts? { tempname_fn?: fun(): string }
--- @return neotest-java.OutputWriter
--- @return { filepath: string, data: string }[]
local function make_writer(opts)
	opts = opts or {}
	local written = {}

	local counter = 0
	local tempname_fn = opts.tempname_fn or function()
		counter = counter + 1
		return "/fake/tmp-" .. counter
	end

	local writer = OutputWriter({
		tempname_fn = tempname_fn,
		open_file = function(filepath)
			return {
				write = function(_, data)
					table.insert(written, { filepath = filepath, data = data })
				end,
				close = function() end,
			}
		end,
		-- run synchronously (instead of nio.run) so tests can assert on
		-- `written` immediately after calling write(), with no scheduling.
		run = function(fn)
			fn()
		end,
	})

	return writer, written
end

describe("OutputWriter", function()
	it("returns nil and writes nothing when data is nil", function()
		local writer, written = make_writer()

		local filepath = writer.write(nil)

		eq(nil, filepath)
		eq({}, written)
	end)

	it("returns nil and writes nothing when data is an empty table", function()
		local writer, written = make_writer()

		local filepath = writer.write({})

		eq(nil, filepath)
		eq({}, written)
	end)

	it("writes a plain string to a new tempfile and returns its path", function()
		local writer, written = make_writer({
			tempname_fn = function()
				return "/fake/tmp-1"
			end,
		})

		local filepath = writer.write("hello world")

		eq("/fake/tmp-1", filepath)
		eq({ { filepath = "/fake/tmp-1", data = "hello world" } }, written)
	end)

	it("joins an array of lines with the visual separator, in order", function()
		local writer, written = make_writer()

		writer.write({ "line one", "line two" })

		eq("line one" .. LINE_SEPARATOR .. "line two", written[1].data)
	end)

	it("flattens nested tables before writing, preserving order", function()
		local writer, written = make_writer()

		writer.write({ { "nested one" }, "top level" })

		eq("nested one" .. LINE_SEPARATOR .. "top level", written[1].data)
	end)

	it("uses a fresh tempname for every write() call", function()
		local writer, written = make_writer()

		local first = writer.write("a")
		local second = writer.write("b")

		assert(first ~= second, "each write() should get its own tempfile: got " .. tostring(first) .. " twice")
		eq({
			{ filepath = first, data = "a" },
			{ filepath = second, data = "b" },
		}, written)
	end)
end)
