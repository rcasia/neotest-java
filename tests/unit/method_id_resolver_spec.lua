local assertions = require("tests.assertions")
local eq = assertions.eq

local Path = require("neotest-java.model.path")

--- @class MethodIdResolver
--- @field public resolve_complete_method_id fun(classname: string, method_id: string): string

--- @class neotest-java.CommandExecutor
--- @field execute_command fun(command: string, args: string[]): { stdout: string, stderr: string, exit_code: number }

--- @class MethodIdResolver.Dependencies
--- @field classpath_provider neotest-java.ClasspathProvider
--- @field command_executor neotest-java.CommandExecutor

--- @param deps MethodIdResolver.Dependencies
--- @return MethodIdResolver
local MethodIdResolver = function(deps)
	--- @type MethodIdResolver
	return {
		resolve_complete_method_id = function(classname, method_id)
			-- TODO: Should take module dir as parameter
			local module_dir = Path("my_module_dir")
			local classpath = deps.classpath_provider.get_classpath(module_dir)

			-- TODO: take javap from the jdtls binary path
			local result =
				deps.command_executor.execute_command("bash", { "-c", "javap", "-cp=" .. classpath, classname })

			local pattern = "%s*([%w%.$<>_]+)%s+([%w_]+)%s*%(([^)]*)%)"
			local filtered_result = vim.iter(result.stdout:gmatch(pattern))
				:map(function(return_type, name, params)
					return { return_type = return_type, name = name, params = params }
				end)
				:filter(function(entry)
					return entry.name == method_id
				end)
				:totable()

			return ("%s(%s)"):format(filtered_result[1].name, filtered_result[1].params)
		end,
	}
end

describe("Method Id Resolver", function()
	--- @type neotest-java.ClasspathProvider
	local fake_classpath_provider = {
		get_classpath = function(base_dir)
			eq(Path("my_module_dir"), base_dir, "base_dir should be passed correctly")
			return "my_classpath"
		end,
	}
	local fake_command_executor_invocations

	--- @type neotest-java.CommandExecutor
	local fake_command_executor = {
		execute_command = function(command, args)
			fake_command_executor_invocations[#fake_command_executor_invocations + 1] =
				{ command = command, args = args }

			return {
				stdout = [[
    Compiled from "Something1Test.java"
    public class com.example.application.Something1Test {
        public com.example.application.Something1Test();
        void testSomething();
        void testSomething1();
        void someMonths_scv(int, java.lang.String, java.lang.Integer, com.example.application.model.TestArgs$Role);
        void someMonths_enum(com.example.application.Something1Test$TestMonth);
        void testPersonFromCsv(com.example.model.Person);
        void testPersonAge(com.example.model.Person);
        static java.util.stream.Stream<com.example.model.Person> personProvider();
    }
				]],
				stderr = "",
				exit_code = 0,
			}
		end,
	}

	before_each(function()
		fake_command_executor_invocations = {}
	end)

	it("works", function()
		local resolver = MethodIdResolver({ --
			classpath_provider = fake_classpath_provider,
			command_executor = fake_command_executor,
		})

		local result = resolver.resolve_complete_method_id("com.example.ExampleTest", "someMonths_scv")

		eq(1, #fake_command_executor_invocations, "command_executor should be invoked once")
		eq(
			{ command = "bash", args = { "-c", "javap", "-cp=my_classpath", "com.example.ExampleTest" } },
			fake_command_executor_invocations[1]
		)
		eq(
			"someMonths_scv(int, java.lang.String, java.lang.Integer, com.example.application.model.TestArgs$Role)",
			result
		)
	end)
end)
