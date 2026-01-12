local Tree = require("neotest.types").Tree
local Path = require("neotest-java.model.path")

local path = Path("MyTest.java")
local key_fn = function(x)
	return x
end
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
		}, key_fn)
	end,

	PARAMETERIZED_TEST = Tree.from_list({
		id = "com.example.ExampleTest#parameterizedMethodShouldFail(java.lang.Integer, java.lang.Integer)",
		name = "parameterizedMethodShouldFail",
		path = path:to_string(),
		range = { 2, 2, 5, 3 },
		type = "test",
	}, key_fn),
	PARAMETERIZED_TEST2 = Tree.from_list({
		{
			id = "com.example.ParameterizedMethodTest",
			name = "ParameterizedMethodTest",
			path = path:to_string(),
			range = { 0, 0, 50, 0 },
			type = "file",
		},
		{
			id = "com.example.ParameterizedMethodTest#parameterizedMethodShouldFail(java.lang.Integer, java.lang.Integer)",
			name = "parameterizedMethodShouldFail",
			path = path:to_string(),
			range = { 2, 2, 5, 3 },
			type = "test",
		},
		{
			id = "com.example.ParameterizedMethodTest#parameterizedMethodShouldNotFail(java.lang.Integer, java.lang.Integer, java.lang.Integer)",
			name = "parameterizedMethodShouldNotFail",
			path = path:to_string(),
			range = { 10, 2, 15, 3 },
			type = "test",
		},
	}, key_fn),

	NESTED_TESTS = Tree.from_list({
		{
			id = path:to_string(),
			name = path:to_string(),
			path = path:to_string(),
			range = { 0, 0, 15, 2 },
			type = "file",
		},
		{
			{
				id = "com.example.SomeTest",
				name = "SomeTest",
				path = path:to_string(),
				range = { 0, 0, 14, 1 },
				type = "namespace",
			},
			{
				{
					id = "com.example.SomeTest$SomeNestedTest",
					name = "SomeNestedTest",
					path = path:to_string(),
					range = { 1, 4, 13, 5 },
					type = "namespace",
				},
				{
					{
						id = "com.example.SomeTest$SomeNestedTest$AnotherNestedTest",
						name = "AnotherNestedTest",
						path = path:to_string(),
						range = { 2, 8, 7, 9 },
						type = "namespace",
					},
					{
						{
							id = "com.example.SomeTest$SomeNestedTest$AnotherNestedTest#someTest()",
							name = "someTest",
							path = path:to_string(),
							range = { 3, 12, 6, 13 },
							type = "test",
						},
					},
				},
				{
					{
						id = "com.example.SomeTest$SomeNestedTest#oneMoreOuterTest()",
						name = "oneMoreOuterTest",
						path = path:to_string(),
						range = { 9, 8, 12, 9 },
						type = "test",
					},
				},
			},
		},
	}, key_fn),
}

return TREES
