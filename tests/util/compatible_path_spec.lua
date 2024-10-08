local compatible_path = require("neotest-java.util.compatible_path")

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
			},
			{
				description = "relative path",
				input = "expenses-domain\\target",
				expected = "expenses-domain/target",
			},
			{
				description = "relative path with dot",
				input = ".\\expenses-domain\\target",
				expected = "./expenses-domain/target",
			},
			{
				description = "with a dot between file separators",
				input = "\\PP\\expense-app-v3\\expenses-domain\\.\\target",
				expected = "/PP/expense-app-v3/expenses-domain/target",
			},
			{
				description = "mixed file separators",
				input = "\\PP\\expense-app-v3/expenses-domain\\./target",
				expected = "/PP/expense-app-v3/expenses-domain/target",
			},
		}

		for _, case in ipairs(testcases) do
			it(("(unix) case: %s -> %s"):format(case.description, case.input), function()
				assert.same(case.expected, compatible_path(case.input), case.description)
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
			},
			{
				description = "relative path",
				input = "expenses-domain/target",
				expected = "expenses-domain\\target",
			},
			{
				description = "relative path with dot",
				input = "./expenses-domain/target",
				expected = ".\\expenses-domain\\target",
			},
			{
				description = "with a dot between file separators",
				input = "/PP/expense-app-v3/expenses-domain/./target",
				expected = "\\PP\\expense-app-v3\\expenses-domain\\target",
			},
			{
				description = "mixed file separators",
				input = "/PP/expense-app-v3\\expenses-domain\\./target",
				expected = "\\PP\\expense-app-v3\\expenses-domain\\target",
			},
		}

		for _, case in ipairs(testcases) do
			-- mock vim.fn.has to simulate to be on windows
			vim.fn.has = function(arg) -- luacheck: ignore 122 Setting a read-only field of a global variable
				if arg == "win64" or arg == "win32" then
					return 1
				else
					return 0
				end
			end
			it(("(windows) case: %s -> %s "):format(case.description, case.input), function()
				local result = compatible_path(case.input)
				assert.same(case.expected, result, case.description)
			end)
		end
	end
end)
