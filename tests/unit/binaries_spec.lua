local assertions = require("tests.assertions")
local eq = assertions.eq

local Binaries = require("neotest-java.command.binaries")
local Path = require("neotest-java.model.path")

describe("Binaries", function()
	local expected_cwd = Path("some")

	local test_client_provider = function(cwd)
		eq(expected_cwd, cwd)
		return {
			request = function(_, method, params, callback)
				eq(method, "workspace/executeCommand")
				eq(params.command, "java.project.getSettings")
				eq(params.arguments[1], "file://some")
				eq(params.arguments[2], { "org.eclipse.jdt.ls.core.vm.location" })

				if callback then
					callback(nil, { ["org.eclipse.jdt.ls.core.vm.location"] = "my_java_home" })
				end
			end,
		}
	end

	it("resolves jdtls java binary", function()
		local bin = Binaries({ client_provider = test_client_provider })
		local result = bin.java(expected_cwd)
		eq(Path("my_java_home/bin/java"), result)
	end)

	it("resolves jdtls javap binary", function()
		local bin = Binaries({ client_provider = test_client_provider })
		local result = bin.javap(expected_cwd)
		eq(Path("my_java_home/bin/javap"), result)
	end)
end)
