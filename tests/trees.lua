local Tree = require("neotest.types").Tree
local Path = require("neotest-java.model.path")

local TREES = {
	--- @param path neotest-java.Path
	TWO_TESTS_IN_FILE = function(path)
		return Tree.from_list({
			{
				id = path:to_string(),
				name = path:to_string(),
				path = path:to_string(),
				range = { 0, 0, 13, 2 },
				type = "file",
			},
			{
				{
					id = "com.example.ExampleTest",
					name = "ExampleTest",
					path = path:to_string(),
					range = { 0, 0, 12, 1 },
					type = "namespace",
				},
				{
					{
						id = "com.example.ExampleTest#firstTestMethod()",
						name = "firstTestMethod",
						path = path:to_string(),
						range = { 2, 2, 5, 3 },
						type = "test",
					},
				},
				{
					{
						id = "com.example.ExampleTest#secondTestMethod()",
						name = "secondTestMethod",
						path = path:to_string(),
						range = { 7, 2, 10, 3 },
						type = "test",
					},
				},
			},
		}, function(x)
			return x
		end)
	end,
}

return TREES
