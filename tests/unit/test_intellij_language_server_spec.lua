local Path = require("neotest-java.model.path")
local assertions = require("tests.assertions")
local eq = assertions.eq
local async = require("tests.async_helpers").async

local LanguageServer = require("neotest-java.core.language_server")

describe("JavaLanguageServer (intellij)", function()
	local sync_schedule = function(fn)
		fn()
	end

	--- Fake intellij client answering protocol commands.
	local function stub_client_provider(calls, responses)
		responses = responses or {}
		return function(_)
			return {
				name = "intellij",
				initialized = true,
				request = function(_, _method, params, callback)
					table.insert(calls, params.command or params)
					if params.command == "intellij.java.resolveLaunch" then
						local default_res = {
							classpath = { "classes_dir", "dep.jar" },
							modulePath = { "mod.jar" },
							javaExec = Path("/usr/lib/jvm/default/bin/java"):to_string(),
						}
						callback(nil, responses.resolveLaunch or default_res)
					elseif params.command == "intellij.java.resolveBuildCommand" then
						local default_build = {
							command = { "./mvnw", "test-compile" },
							cwd = "/path/to/project",
							supported = true,
						}
						callback(nil, responses.resolveBuildCommand or default_build)
					end
				end,
			}
		end
	end

	it(
		"resolves java home from javaExec via resolveLaunch",
		async(function()
			local calls = {}
			local server = LanguageServer.new({
				client_provider = stub_client_provider(calls, {
					resolveLaunch = {
						javaExec = Path("/custom/jdk-21/bin/java"):to_string(),
					},
				}),
				schedule = sync_schedule,
			})
			eq(Path("/custom/jdk-21"), server.get_java_home(Path("some")))
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
			local launch_calls = vim.tbl_filter(function(c)
				return c == "intellij.java.resolveLaunch"
			end, calls)
			eq(2, #launch_calls)
		end)
	)

	it(
		"merges classpath, modulePath, and extra entries with ':' separator",
		async(function()
			local server = LanguageServer.new({
				client_provider = stub_client_provider({}),
				schedule = sync_schedule,
				path_separator = ":",
			})
			eq(
				"classes_dir:dep.jar:mod.jar:additional",
				tostring(server.get_classpath(Path("some"), { Path("additional") }))
			)
		end)
	)

	it(
		"merges classpath, modulePath, and extra entries with ';' separator",
		async(function()
			local server = LanguageServer.new({
				client_provider = stub_client_provider({}),
				schedule = sync_schedule,
				path_separator = ";",
			})
			eq(
				"classes_dir;dep.jar;mod.jar;additional",
				tostring(server.get_classpath(Path("some"), { Path("additional") }))
			)
		end)
	)

	it("executes build command returned by resolveBuildCommand", function()
		local system_invocations = {}
		local fake_system = function(cmd, opts)
			table.insert(system_invocations, { cmd = cmd, opts = opts })
			return {
				wait = function()
					return { code = 0 }
				end,
			}
		end

		local server = LanguageServer.new({
			client_provider = stub_client_provider({}, {
				resolveBuildCommand = {
					command = { "./mvnw", "-pl", ":app", "test-compile" },
					cwd = "/workspace/app",
					supported = true,
				},
			}),
			schedule = sync_schedule,
			system = fake_system,
		})

		server.compile({ base_dir = Path("/workspace/app"), compile_mode = "full" })

		eq(1, #system_invocations)
		eq({ "./mvnw", "-pl", ":app", "test-compile" }, system_invocations[1].cmd)
		eq("/workspace/app", system_invocations[1].opts.cwd)
	end)

	it("skips execution when resolveBuildCommand reports supported=false", function()
		local system_invocations = {}
		local fake_system = function(cmd, opts)
			table.insert(system_invocations, { cmd = cmd, opts = opts })
			return {
				wait = function()
					return { code = 0 }
				end,
			}
		end

		local server = LanguageServer.new({
			client_provider = stub_client_provider({}, {
				resolveBuildCommand = {
					supported = false,
					reason = "plain JPS project",
				},
			}),
			schedule = sync_schedule,
			system = fake_system,
		})

		server.compile({ base_dir = Path("/workspace/app"), compile_mode = "incremental" })

		eq(0, #system_invocations)
	end)

	it(
		"resolves test file URI from globpath when base_dir is a directory",
		async(function()
			local passed_uri = nil
			local fake_client = function(_)
				return {
					name = "intellij",
					initialized = true,
					request = function(_, _, params, callback)
						passed_uri = params.arguments and params.arguments[1] and params.arguments[1].uri
						callback(nil, { classpath = { "target/test-classes" } })
					end,
				}
			end

			local server = LanguageServer.new({
				client_provider = fake_client,
				schedule = sync_schedule,
				globpath = function(_, pattern, _, _)
					if pattern:find("src/test") then
						return { Path("/workspace/app/src/test/java/ExampleTest.java"):to_string() }
					end
					return {}
				end,
			})

			server.get_classpath(Path("/workspace/app"))
			eq(vim.uri_from_fname(Path("/workspace/app/src/test/java/ExampleTest.java"):to_string()), passed_uri)
		end)
	)
end)
