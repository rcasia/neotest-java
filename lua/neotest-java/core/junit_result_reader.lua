local nio = require("nio")
local JunitResult = require("neotest-java.model.junit_result")
local XmlReader = require("neotest-java.util.xml_reader").new

--- @class neotest-java.JunitResultReaderDeps
--- @field xml_reader? neotest-java.XmlReader
--- @field tempname_fn? fun(): string
--- @field log? neotest.Logger

--- @class neotest-java.JunitResultReader
--- @field read_all fun(paths: neotest-java.Path[]): neotest-java.JunitResult[]

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
								table.insert(results, JunitResult:new(tc, deps.tempname_fn()))
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
