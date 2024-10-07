-- Test file

local u = require("neotest-java.util.find_module_by_filepath")

describe("find_module_by_filepath function", function()
	local test_cases = {
		{
			description = "Standard case with module in the path",
			module_dirs = { "rest-module", "grpc-module", "infrastructure-module", "domain-module" },
			filepath = "./code/domain-module/src/test/org/app/Test.java",
			expected = "domain-module",
		},
		{
			description = "Standard case with module in the path for windows",
			module_dirs = { "rest-module", "grpc-module", "infrastructure-module", "domain-module" },
			filepath = ".\\code\\domain-module\\src\\test\\org\\app\\Test.java",
			expected = "domain-module",
		},
		{
			description = "Module not present in the path",
			module_dirs = { "rest-module", "grpc-module", "infrastructure-module", "domain-module" },
			filepath = "./code/unknown-module/src/test/org/app/Test.java",
			expected = nil,
		},
		{
			description = "Filepath contains module name as substring",
			module_dirs = { "rest", "grpc", "infrastructure", "domain" },
			filepath = "./code/restful/src/test/org/app/Test.java",
			expected = nil,
		},
		{
			description = "Module name at the start of the path",
			module_dirs = { "rest", "grpc", "infrastructure", "domain" },
			filepath = "rest/src/test/org/app/Test.java",
			expected = "rest",
		},
		{
			description = "Module name at the end of the path",
			module_dirs = { "rest", "grpc", "infrastructure", "domain" },
			filepath = "./code/src/test/org/app/domain",
			expected = "domain",
		},
		{
			description = "Module name with special characters",
			module_dirs = { "rest-module", "grpc-module", "infrastructure-module", "domain-module" },
			filepath = "./code/infrastructure-module/src/test/org/app/Test.java",
			expected = "infrastructure-module",
		},
		{
			description = "Multiple modules with similar names",
			module_dirs = { "module", "module-test", "module-prod" },
			filepath = "./code/module-test/src/test/org/app/Test.java",
			expected = "module-test",
		},
		{
			description = "Empty module_dirs list",
			module_dirs = {},
			filepath = "./code/domain-module/src/test/org/app/Test.java",
			expected = nil,
		},
		{
			description = "Empty filepath",
			module_dirs = { "rest-module", "grpc-module", "infrastructure-module", "domain-module" },
			filepath = "",
			expected = nil,
		},
		{
			description = "Module name with regex special characters",
			module_dirs = { "rest+module", "grpc-module", "infrastructure-module", "domain-module" },
			filepath = "./code/rest+module/src/test/org/app/Test.java",
			expected = "rest+module",
		},
		{
			description = "Real example that was failing",
			module_dirs = {
				"./neovim-java",
				"./neovim-java/api-explorer",
				"./neovim-java/core-rpc",
				"./neovim-java/handler-annotations",
				"./neovim-java/neovim-api",
				"./neovim-java/neovim-notifications",
				"./neovim-java/neovim-rx-api",
				"./neovim-java/plugin-host",
				"./neovim-java/plugins-common-host",
				"./neovim-java/reactive-core-rpc",
				"./neovim-java/rplugin-example",
				"./neovim-java/rplugin-example",
				"./neovim-java/rplugin-hosted-example",
				"./neovim-java/testing-helpers",
				"./neovim-java/unix-socket-connection",
			},
			filepath = "./neovim-java/core-rpc/src/test/java/com/ensarsarajcic/neovim/java/corerpc/client/AsyncRpcSenderTest.java",
			expected = "./neovim-java/core-rpc",
		},
	}

	for _, case in ipairs(test_cases) do
		it(case.description, function()
			assert.same(case.expected, u(case.module_dirs, case.filepath))
		end)
	end
end)
