local Path = require("neotest-java.model.path")

local assertions = require("tests.assertions")
local eq = assertions.eq
local async = require("tests.async_helpers").async

local ClasspathProvider = require("neotest-java.core.spec_builder.compiler.classpath_provider")

describe("Classpath Provider", function()
	local sync_schedule = function(fn)
		fn()
	end

	--- @param path_separator string The separator to inject (":" for Unix, ";" for Windows)
	--- @return neotest-java.ClasspathProvider
	local function create_provider(path_separator)
		return ClasspathProvider({
			schedule = sync_schedule,
			path_separator = path_separator,
			client_provider = function()
				return {
					attached_buffers = { [1234] = true },
					request = function(_, _, params, callback)
						local options = vim.json.decode(params.arguments[2])
						if options.scope == "runtime" then
							callback(nil, { classpaths = { "source_classpath" } })
						elseif options.scope == "test" then
							callback(nil, { classpaths = { "test_classpath" } })
						end
					end,
				}
			end,
		})
	end

	it(
		"uses ':' separator on Unix",
		async(function()
			local provider = create_provider(":")
			local result = provider.get_classpath(Path("some"), { Path("additional") })
			eq("source_classpath:test_classpath:additional", result)
		end)
	)

	it(
		"uses ';' separator on Windows",
		async(function()
			local provider = create_provider(";")
			local result = provider.get_classpath(Path("some"), { Path("additional") })
			eq("source_classpath;test_classpath;additional", result)
		end)
	)
end)
