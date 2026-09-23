local Path = require("neotest-java.model.path")

local assertions = require("tests.assertions")
local eq = assertions.eq
local async = require("tests.async_helpers").async

local ClasspathProvider = require("neotest-java.core.spec_builder.compiler.classpath_provider")

describe("Classpath Provider", function()
	it(
		"forwards to the language server gateway",
		async(function()
			local seen_base, seen_extra
			local provider = ClasspathProvider({
				---@diagnostic disable-next-line: missing-fields
				language_server = {
					get_classpath = function(base_dir, additional)
						seen_base = base_dir
						seen_extra = additional
						return "source_classpath:test_classpath:additional"
					end,
				},
			})
			local result = provider.get_classpath(Path("some"), { Path("additional") })
			eq("source_classpath:test_classpath:additional", result)
			eq(Path("some"), seen_base)
			eq({ Path("additional") }, seen_extra)
		end)
	)
end)
