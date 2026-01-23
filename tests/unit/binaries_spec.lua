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

	it("uses the cached binary after the first first time", function()
		local some_cwd = Path("some")
		local another_cwd = Path("another")
		local invocation_count = 0
		local bin = Binaries({
			client_provider = function()
				return {
					request = function(_, _, _, callback)
						invocation_count = invocation_count + 1
						callback(nil, { ["org.eclipse.jdt.ls.core.vm.location"] = "my_java_home" })
					end,
				}
			end,
		})

		for _ = 1, 10 do
			bin.java(some_cwd)
			bin.javap(some_cwd)
			bin.java(another_cwd)
			bin.javap(another_cwd)
		end

		assert(invocation_count == 2, "Expected two invocations of the LSP request, got " .. invocation_count)
	end)
end)
