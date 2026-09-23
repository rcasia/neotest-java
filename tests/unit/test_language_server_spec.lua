local Path = require("neotest-java.model.path")

local assertions = require("tests.assertions")
local eq = assertions.eq
local async = require("tests.async_helpers").async

local LanguageServer = require("neotest-java.core.language_server")

describe("JavaLanguageServer (jdtls)", function()
	local sync_schedule = function(fn)
		fn()
	end

	--- Fake jdtls client answering all three protocol commands.
	local function stub_client_provider(calls)
		return function(_)
			return {
				initialized = true,
				attached_buffers = { [1234] = true },
				request = function(_, _method, params, callback)
					table.insert(calls, params.command or params)
					if params.command == "java.project.getSettings" then
						callback(nil, { ["org.eclipse.jdt.ls.core.vm.location"] = "my_java_home" })
					elseif params.command == "java.project.getClasspaths" then
						local options = vim.json.decode(params.arguments[2])
						if options.scope == "runtime" then
							callback(nil, { classpaths = { "source_classpath" } })
						elseif options.scope == "test" then
							callback(nil, { classpaths = { "test_classpath" } })
						end
					elseif params == "java/buildWorkspace" then
						callback(nil, { modulepaths = {} })
					end
				end,
			}
		end
	end

	it(
		"resolves java home via getSettings",
		async(function()
			local calls = {}
			local server = LanguageServer.new({
				client_provider = stub_client_provider(calls),
				schedule = sync_schedule,
			})
			eq(Path("my_java_home"), server.get_java_home(Path("some")))
		end)
	)

	it(
		"caches java home per directory",
		async(function()
			local calls = {}
			local server = LanguageServer.new({
				client_provider = stub_client_provider(calls),
				schedule = sync_schedule,
			})
			for _ = 1, 10 do
				server.get_java_home(Path("some"))
				server.get_java_home(Path("another_path"))
			end
			local settings_calls = vim.tbl_filter(function(c)
				return c == "java.project.getSettings"
			end, calls)
			eq(2, #settings_calls)
		end)
	)

	it(
		"merges runtime and test classpaths with ':' separator",
		async(function()
			local server = LanguageServer.new({
				client_provider = stub_client_provider({}),
				schedule = sync_schedule,
				path_separator = ":",
			})
			eq(
				"source_classpath:test_classpath:additional",
				tostring(server.get_classpath(Path("some"), { Path("additional") }))
			)
		end)
	)

	it(
		"merges runtime and test classpaths with ';' separator",
		async(function()
			local server = LanguageServer.new({
				client_provider = stub_client_provider({}),
				schedule = sync_schedule,
				path_separator = ";",
			})
			eq(
				"source_classpath;test_classpath;additional",
				tostring(server.get_classpath(Path("some"), { Path("additional") }))
			)
		end)
	)

	it("maps compile modes to forceRebuild", function()
		local seen = {}
		local server = LanguageServer.new({
			client_provider = function(_)
				return {
					initialized = true,
					request = function(_, params, opts)
						eq("java/buildWorkspace", params)
						table.insert(seen, opts)
						return true
					end,
				}
			end,
			schedule = sync_schedule,
		})

		server.compile({ base_dir = Path("/path/to/project"), compile_mode = "incremental" })
		server.compile({ base_dir = Path("/path/to/project"), compile_mode = "full" })

		eq({ { forceRebuild = false }, { forceRebuild = true } }, seen)
	end)
end)
