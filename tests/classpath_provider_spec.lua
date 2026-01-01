local Path = require("neotest-java.model.path")

local assertions = require("tests.assertions")
local eq = assertions.eq

local ClasspathProvider = require("neotest-java.core.spec_builder.compiler.classpath_provider")

describe("Classpath Provider", function()
	it("works", function()
		local base_dir = Path("some")
		local classpath_provider = ClasspathProvider({
			client_provider = function(_base_dir)
				eq(base_dir, _base_dir)

				return {
					request_sync = function(_, method, params)
						eq(method, "workspace/executeCommand")
						eq(params.command, "java.project.getClasspaths")
						-- eq(params.arguments[1], "test-uri") -- TODO: look at it later
						assert(params.arguments[2], "Expected second argument to be present")
						local options = vim.json.decode(params.arguments[2])

						if options.scope == "runtime" then
							return { result = { classpaths = { "source_classpath" } } }
						end

						if options.scope == "test" then
							return { result = { classpaths = { "test_classpath" } } }
						end

						error("Unexpected scope: " .. tostring(options.scope))
					end,
				}
			end,
		})

		eq(
			"source_classpath:test_classpath:additional_classpath",
			classpath_provider.get_classpath(base_dir, { Path("additional_classpath") })
		)
	end)
end)
