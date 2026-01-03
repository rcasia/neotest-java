local assertions = require("tests.assertions")
local eq = assertions.eq

local Binaries = require("neotest-java.command.binaries")
local Path = require("neotest-java.model.path")

describe("Binaries", function()
	it("works", function()
		local expected_cwd = Path("some")

		local test_client_provider = function(cwd)
			eq(expected_cwd, cwd)
			return {
				request_sync = function(_, method, params)
					eq(method, "workspace/executeCommand")
					eq(params.command, "java.project.getSettings")
					eq(params.arguments[1], "file://some")
					eq(params.arguments[2], { "org.eclipse.jdt.ls.core.vm.location" })

					return { result = { ["org.eclipse.jdt.ls.core.vm.location"] = "my_java_home" } }
				end,
			}
		end

		local bin = Binaries({ client_provider = test_client_provider })
		local result = bin.java(expected_cwd)
		eq("my_java_home/bin/java", result)
	end)
end)
