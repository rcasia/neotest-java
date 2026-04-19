local Path = require("neotest-java.model.path")

local assertions = require("tests.assertions")
local eq = assertions.eq
local it = require("nio").tests.it

local ClasspathProvider = require("neotest-java.core.spec_builder.compiler.classpath_provider")

describe("Classpath Provider", function()
	it("works", function()
		local base_dir = Path("some")
		local classpath_provider = ClasspathProvider({
			client_provider = function(base_dir_arg)
				eq(base_dir, base_dir_arg)

				return {
					attached_buffers = { [1234] = true },
					request = function(_, method, params, callback)
						eq(method, "workspace/executeCommand")
						eq(params.command, "java.project.getClasspaths")
						eq(params.arguments[1], "file://some")
						assert(params.arguments[2], "Expected second argument to be present")
						local options = vim.json.decode(params.arguments[2])

						if options.scope == "runtime" then
							callback(nil, { classpaths = { "source_classpath" } })
						elseif options.scope == "test" then
							callback(nil, { classpaths = { "test_classpath" } })
						else
							error("Unexpected scope: " .. tostring(options.scope))
						end
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
