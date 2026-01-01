local Project = require("neotest-java.model.project")
local Path = require("neotest-java.model.path")

local eq = assert.are.same

describe("project", function()
	local testscases = {
		{
			input = {
				root_dir = Path("./tests/fixtures/maven-demo"),
				dirs = {
					Path("./tests/fixtures/maven-demo/pom.xml"),
				},
				project_filename = "pom.xml",
			},
			expected = {
				{ name = "maven-demo", base_dir = Path("./tests/fixtures/maven-demo") },
			},
		},
		{
			input = {
				root_dir = Path("./tests/fixtures/maven-demo"),
				dirs = {
					Path("./my_project/pom.xml"),
					Path("./my_project/module-a/pom.xml"),
					Path("./my_project/module-b/pom.xml"),
				},
				project_filename = "pom.xml",
			},
			expected = {
				{ name = "my_project", base_dir = Path("./my_project") },
				{ name = "module-a", base_dir = Path("./my_project/module-a") },
				{ name = "module-b", base_dir = Path("./my_project/module-b") },
			},
		},
		{
			input = {
				root_dir = Path("./tests/fixtures/gradle-groovy-demo"),
				dirs = {
					Path("./tests/fixtures/gradle-groovy-demo/build.gradle"),
				},
				project_filename = "build.gradle",
			},
			expected = {
				{ name = "gradle-groovy-demo", base_dir = Path("./tests/fixtures/gradle-groovy-demo") },
			},
		},
		{
			input = {
				root_dir = Path("./tests/fixtures/maven-demo"),
				dirs = {
					Path("./my_project/build.gradle"),
					Path("./my_project/module-a/build.gradle"),
					Path("./my_project/module-b/build.gradle"),
				},
				project_filename = "build.gradle",
			},
			expected = {
				{ name = "my_project", base_dir = Path("./my_project") },
				{ name = "module-a", base_dir = Path("./my_project/module-a") },
				{ name = "module-b", base_dir = Path("./my_project/module-b") },
			},
		},
	}
	for _, testcase in ipairs(testscases) do
		it("should get modules: " .. testcase.input.root_dir.to_string(), function()
			local project = Project.from_dirs_and_project_file(testcase.input.dirs, testcase.input.project_filename)

			local results = {}
			for _, mod in ipairs(project:get_modules()) do
				results[#results + 1] = { name = mod.name, base_dir = mod.base_dir }
			end
			eq(testcase.expected, results)
		end)
	end

	it("find module by filepath", function()
		local project = Project.from_dirs_and_project_file({

			Path("./tests/fixtures/multi-module-demo/pom.xml"),
			Path("./tests/fixtures/multi-module-demo/module-a/pom.xml"),
			Path("./tests/fixtures/multi-module-demo/module-b/pom.xml"),
		}, "pom.xml")

		local not_found_module = project:find_module_by_filepath(Path("./tests/fixtures/some-other-project"))
		eq(nil, not_found_module)

		local module_a = project:find_module_by_filepath(
			Path("./tests/fixtures/multi-module-demo/module-a/src/main/java/com/example/App.java")
		)
		assert(module_a)
		eq("module-a", module_a.name)

		local module_b = project:find_module_by_filepath(
			Path("./tests/fixtures/multi-module-demo/module-b/src/main/java/com/example/App.java")
		)
		assert(module_b)
		eq("module-b", module_b.name)

		local root_module = project:find_module_by_filepath(
			Path("./tests/fixtures/multi-module-demo/src/main/java/com/example/App.java")
		)
		assert(root_module)
		eq("multi-module-demo", root_module.name)
	end)
end)
