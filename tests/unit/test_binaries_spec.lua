local assertions = require("tests.assertions")
local eq = assertions.eq

local Binaries = require("neotest-java.command.binaries")
local Path = require("neotest-java.model.path")

describe("Binaries", function()
	local expected_cwd = Path("some")

	local language_server_stub = function(java_home)
		return {
			get_java_home = function(cwd)
				eq(expected_cwd, cwd)
				return Path(java_home)
			end,
		}
	end

	it("resolves java binary", function()
		local bin = Binaries({
			language_server = language_server_stub("my_java_home"),
			is_windows = false,
		})
		local result = bin.java(expected_cwd)
		eq(Path("my_java_home/bin/java"), result)
	end)

	it("resolves javap binary", function()
		local bin = Binaries({
			language_server = language_server_stub("my_java_home"),
			is_windows = false,
		})
		local result = bin.javap(expected_cwd)
		eq(Path("my_java_home/bin/javap"), result)
	end)

	it("adds .exe extension on Windows", function()
		local bin = Binaries({
			language_server = language_server_stub("my_java_home"),
			is_windows = true,
		})
		local java_result = bin.java(expected_cwd)
		local javap_result = bin.javap(expected_cwd)
		eq(Path("my_java_home/bin/java.exe"), java_result)
		eq(Path("my_java_home/bin/javap.exe"), javap_result)
	end)

	it("falls back to client_provider with default jdtls behavior", function()
		local sync_schedule = function(fn)
			fn()
		end
		local bin = Binaries({
			client_provider = function(cwd)
				eq(expected_cwd, cwd)
				return {
					request = function(_, method, params, callback)
						eq(method, "workspace/executeCommand")
						eq(params.command, "java.project.getSettings")
						if callback then
							callback(nil, { ["org.eclipse.jdt.ls.core.vm.location"] = "my_java_home" })
						end
					end,
				}
			end,
			is_windows = false,
			schedule = sync_schedule,
		})
		eq(Path("my_java_home/bin/java"), bin.java(expected_cwd))
	end)
end)
