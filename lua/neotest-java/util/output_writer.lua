--- OutputWriter
---
--- The single place in this codebase that writes test output to a
--- temporary file for neotest to read back (`neotest.Result.output`
--- expects a filepath, not raw text). Everything else — `JunitResult`,
--- `result_builder` — deals only with in-memory output data; this module
--- owns the actual I/O.
---
--- Usage:
---     local OutputWriter = require("neotest-java.util.output_writer")
---     local writer = OutputWriter({ tempname_fn = nio.fn.tempname })
---     local filepath = writer.write({ "line one", "line two" })
---
--- Tests typically inject a stub `tempname_fn` (returns a known path) and
--- a stub `open_file` (records writes without touching the filesystem).

local nio = require("nio")

local LINE_SEPARATOR = "=================================\n"

--- @class neotest-java.OutputWriterDeps
--- @field tempname_fn? fun(): string
--- @field open_file? fun(filepath: string, mode: string): file*|nil, string?
--- @field run? fun(fn: function)

--- @class neotest-java.OutputWriter
--- @field write fun(data: string | table | nil): string | nil

--- @param deps neotest-java.OutputWriterDeps | nil
--- @return neotest-java.OutputWriter
local OutputWriter = function(deps)
	deps = deps or {}
	deps.tempname_fn = deps.tempname_fn or nio.fn.tempname
	deps.open_file = deps.open_file or io.open
	deps.run = deps.run or nio.run

	return {
		--- Writes `data` to a new temporary file and returns its path.
		--- Nested tables (e.g. an array of output lines, possibly containing
		--- further nested arrays) are flattened and joined with a visual
		--- separator before writing.
		--- @param data string | table | nil
		--- @return string | nil filepath
		write = function(data)
			if not data then
				return nil
			end

			if type(data) == "table" then
				if #data == 0 then
					return nil
				end
				data = table.concat(vim.iter(vim.tbl_values(data)):flatten(math.huge):totable(), LINE_SEPARATOR)
			end

			local filepath = deps.tempname_fn()

			deps.run(function()
				local file = assert(deps.open_file(filepath, "w"))
				file:write(data)
				file:close()
			end)

			return filepath
		end,
	}
end

return OutputWriter
