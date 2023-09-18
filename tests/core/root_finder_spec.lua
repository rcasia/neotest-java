local plugin = require("neotest-java")

local function getCurrentDir()
	return vim.fn.fnamemodify(vim.fn.expand("%:p:h"), ":p")
end

describe("RootFinder", function()
	it("should find the root of a project", function()
		-- given
		local relativeDirs = {
			"tests/fixtures/maven-demo/src/main/java/com/example",
			"tests/fixtures/maven-demo/src/test/java/com/example",
			"tests/fixtures/maven-demo/src/main/resources",
			"tests/fixtures/maven-demo/src/test/resources",
			"tests/fixtures/maven-demo/src/main/java/com/example/Example.java",
			"tests/fixtures/maven-demo/src/test/java/com/example/ExampleTest.java",
			"tests/fixtures/maven-demo",
		}

		local absoluteDirs = {}
		for i, dir in ipairs(relativeDirs) do
			absoluteDirs[i] = getCurrentDir() .. dir
		end

		local expectedRoot = getCurrentDir() .. "tests/fixtures/maven-demo"

		-- when
		for _, dir in ipairs(absoluteDirs) do
			local actualRoot = plugin.root(dir)

			-- then
			assert.are.same(expectedRoot, actualRoot)
		end
	end)
end)
