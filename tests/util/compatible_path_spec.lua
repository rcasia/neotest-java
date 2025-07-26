local compatible_path = require("neotest-java.util.compatible_path")
local compatible_path_parent = require("neotest-java.util.compatible_path_parent")

describe("compatible_path", function()
	local original_vim_fn_has

	before_each(function()
		-- save original function
		original_vim_fn_has = vim.fn.has -- luacheck: ignore 122 Setting a read-only field of a global variable
	end)

	after_each(function()
		-- reset
		vim.fn.has = original_vim_fn_has -- luacheck: ignore 122 Setting a read-only field of a global variable
	end)

	-- should create compatible path for unix
	do
		local testcases = {
			{
				description = "basic case",
				input = "\\PP\\expense-app-v3\\expenses-domain\\target",
				expected = "/PP/expense-app-v3/expenses-domain/target",
				expected_parent = "/PP/expense-app-v3/expenses-domain",
			},
			{
				description = "relative path",
				input = "expenses-domain\\target",
				expected = "expenses-domain/target",
				expected_parent = "expenses-domain",
			},
			{
				description = "relative path with dot",
				input = ".\\expenses-domain\\target",
				expected = "./expenses-domain/target",
				expected_parent = "./expenses-domain",
			},
			{
				description = "with a dot between file separators",
				input = "\\PP\\expense-app-v3\\expenses-domain\\.\\target",
				expected = "/PP/expense-app-v3/expenses-domain/target",
				expected_parent = "/PP/expense-app-v3/expenses-domain",
			},
			{
				description = "mixed file separators",
				input = "\\PP\\expense-app-v3/expenses-domain\\./target",
				expected = "/PP/expense-app-v3/expenses-domain/target",
				expected_parent = "/PP/expense-app-v3/expenses-domain",
			},
		}

		for _, case in ipairs(testcases) do
			it(("(unix) case: %s -> %s"):format(case.description, case.input), function()
				vim.fn.has = function(arg) -- luacheck: ignore 122 Setting a read-only field of a global variable
					print("mocking vim.fn.has with arg: " .. arg)
					if arg == "win64" or arg == "win32" then
						return 0
					else
						return 1
					end
				end
				assert.same(case.expected, compatible_path(case.input), case.description)
				assert.same(
					case.expected_parent,
					compatible_path_parent(case.input),
					case.description .. " parent path"
				)
			end)
		end
	end

	-- should create compatible path for windows
	do
		local testcases = {
			{
				description = "basic case for win",
				input = "/PP/expense-app-v3/expenses-domain/target",
				expected = "\\PP\\expense-app-v3\\expenses-domain\\target",
				expected_parent = "\\PP\\expense-app-v3\\expenses-domain",
			},
			{
				description = "relative path",
				input = "expenses-domain/target",
				expected = "expenses-domain\\target",
				expected_parent = "expenses-domain",
			},
			{
				description = "relative path with dot",
				input = "./expenses-domain/target",
				expected = ".\\expenses-domain\\target",
				expected_parent = ".\\expenses-domain",
			},
			{
				description = "with a dot between file separators",
				input = "/PP/expense-app-v3/expenses-domain/./target",
				expected = "\\PP\\expense-app-v3\\expenses-domain\\target",
				expected_parent = "\\PP\\expense-app-v3\\expenses-domain",
			},
			{
				description = "mixed file separators",
				input = "/PP/expense-app-v3\\expenses-domain\\./target",
				expected = "\\PP\\expense-app-v3\\expenses-domain\\target",
				expected_parent = "\\PP\\expense-app-v3\\expenses-domain",
			},
		}

		for _, case in ipairs(testcases) do
			-- mock vim.fn.has to simulate to be on windows
			it(("(windows) case: %s -> %s "):format(case.description, case.input), function()
				vim.fn.has = function(arg) -- luacheck: ignore 122 Setting a read-only field of a global variable
					print("mocking vim.fn.has with arg: " .. arg)
					if arg == "win64" or arg == "win32" then
						return 1
					else
						return 0
					end
				end
				local result = compatible_path(case.input)
				assert.same(case.expected, result, case.description)
				assert.same(
					case.expected_parent,
					compatible_path_parent(case.input),
					case.description .. " parent path"
				)
			end)
		end
	end
end)
