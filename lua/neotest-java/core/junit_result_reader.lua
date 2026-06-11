--- JunitResultReader
---
--- Reads a list of JUnit XML report files and returns a flat array of
--- `JunitResult` objects, one per testcase. Owns the JUnit-format
--- knowledge (where the `testsuite.testcase` lives, how to handle a
--- single-testcase non-array wrap, how to tolerate missing nodes and
--- per-file parse errors) so that callers — notably `result_builder` —
--- can stay pure orchestrators.
---
--- All I/O flows through the injected `XmlReader` (read + parse) and the
--- injected `tempname_fn` (per-result output file). Per-file parse
--- errors are logged via the injected `log` and the file is skipped;
--- the rest of the list is still processed.
---
--- Usage:
---     local JunitResultReader = require("neotest-java.core.junit_result_reader")
---     local reader = JunitResultReader({
---       xml_reader = XmlReader.new({ read_file = my_read_file }),
---       tempname_fn = function() return vim.fn.tempname() end,
---     })
---     local results = reader.read_all(report_files)
---
--- Tests typically inject a stub `xml_reader` (no real I/O) and a stub
--- `tempname_fn` (returns a known path) so the JUnit walk can be
--- exercised without touching the filesystem or async context.

--- @class neotest-java.JunitResultReaderDeps
--- @field xml_reader? neotest-java.XmlReader | { parse: fun(filepath: neotest-java.Path | string): { tree: table, error: string } }
--- @field tempname_fn? fun(): string
--- @field log? neotest.Logger | { debug: fun(...), warn: fun(...) }

--- @class neotest-java.JunitResultReader
--- @field read_all fun(paths: neotest-java.Path[]): neotest-java.JunitResult[]

local nio = require("nio")
local JunitResult = require("neotest-java.model.junit_result")
local XmlReader = require("neotest-java.util.xml_reader").new

--- @param deps neotest-java.JunitResultReaderDeps | nil
--- @return neotest-java.JunitResultReader
local JunitResultReader = function(deps)
	deps = deps or {}
	deps.xml_reader = deps.xml_reader or XmlReader()
	deps.tempname_fn = deps.tempname_fn or nio.fn.tempname
	deps.log = deps.log or require("neotest-java.logger")

	return {
		--- Read all JUnit XML report files at the given paths and return a flat
		--- array of `JunitResult` objects, one per testcase. Per-file parse
		--- errors are logged and skipped (other files are still processed).
		--- @param paths neotest-java.Path[]
		--- @return neotest-java.JunitResult[]
		read_all = function(paths)
			if not paths or #paths == 0 then
				return {}
			end

			deps.log.debug("Found report files: ", paths)

			local results = {}
			for _, filepath in ipairs(paths) do
				local parsed = deps.xml_reader.parse(filepath)
				if parsed.error then
					deps.log.warn("Skipping report (parse error): " .. tostring(filepath) .. " - " .. parsed.error)
				else
					local suite = parsed.tree.testsuite
					if suite then
						local tcs = suite.testcase
						if tcs then
							if not vim.isarray(tcs) then
								tcs = { tcs }
							end
							for _, tc in ipairs(tcs) do
								table.insert(results, JunitResult:new(tc, deps.tempname_fn))
							end
						end
					end
				end
			end
			return results
		end,
	}
end

return JunitResultReader
