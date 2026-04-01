local Project = require("neotest-java.model.project")
local Path = require("neotest-java.model.path")

local eq = assert.are.same

describe("project", function()
	local fake_build_tool_with_artifact_id = {
		get_artifact_id = function(base_dir)
			return "artifact-" .. base_dir:name()
		end,
	}

	local fake_build_tool_dir_name = {
		get_artifact_id = function(base_dir)
			return base_dir:name()
		end,
	}

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
		it("should get modules: " .. testcase.input.root_dir:to_string(), function()
			local project = Project.from_dirs_and_project_file(
				testcase.input.dirs,
				testcase.input.project_filename,
				fake_build_tool_dir_name
			)

			local results = {}
			for _, mod in ipairs(project:get_modules()) do
				results[#results + 1] = { name = mod.name, base_dir = mod.base_dir }
			end
			eq(testcase.expected, results)
		end)
	end

	it("should use artifactId from build tool instead of directory name", function()
		local project = Project.from_dirs_and_project_file({
			Path("./my_project/pom.xml"),
		}, "pom.xml", fake_build_tool_with_artifact_id)

		local modules = project:get_modules()
		assert(#modules == 1)
		eq("artifact-my_project", modules[1].name)
	end)

	it("detects gradle modules with custom build file names (e.g. app.gradle.kts)", function()
		-- Gradle projects can use custom build file names like app.gradle.kts, list.gradle.kts
		-- configured via: project.buildFileName = "${project.name}.gradle.kts" in settings.gradle.kts
		-- The project_filename pattern "%.gradle" should match these custom filenames
		local project = Project.from_dirs_and_project_file({
			Path("./my_project/settings.gradle.kts"),
			Path("./my_project/app.gradle.kts"),
			Path("./my_project/app/app.gradle.kts"),
			Path("./my_project/list/list.gradle.kts"),
			Path("./my_project/utilities/utilities.gradle.kts"),
		}, "%.gradle", fake_build_tool_dir_name)

		local modules = project:get_modules()
		-- settings.gradle.kts should NOT be treated as a module build file
		-- each custom-named .gradle.kts file should create a module
		eq(4, #modules)
		local module_names = vim.iter(modules)
			:map(function(m)
				return m.base_dir:to_string()
			end)
			:totable()
		table.sort(module_names)
		local expected_custom = {
			Path("./my_project"):to_string(),
			Path("./my_project/app"):to_string(),
			Path("./my_project/list"):to_string(),
			Path("./my_project/utilities"):to_string(),
		}
		table.sort(expected_custom)
		eq(expected_custom, module_names)
	end)

	it("does not treat settings.gradle as a module build file", function()
		local project = Project.from_dirs_and_project_file({
			Path("./my_project/settings.gradle"),
			Path("./my_project/build.gradle"),
			Path("./my_project/subproject/build.gradle"),
		}, "%.gradle", fake_build_tool_dir_name)

		local modules = project:get_modules()
		eq(2, #modules)
		local module_names = vim.iter(modules)
			:map(function(m)
				return m.base_dir:to_string()
			end)
			:totable()
		table.sort(module_names)
		local expected_settings = {
			Path("./my_project"):to_string(),
			Path("./my_project/subproject"):to_string(),
		}
		table.sort(expected_settings)
		eq(expected_settings, module_names)
	end)

	it("ignores files from .gradle internal directory when detecting modules", function()
		local project = Project.from_dirs_and_project_file({
			Path("./big_project/settings.gradle.kts"),
			Path("./big_project/app.gradle.kts"),
			Path("./big_project/service/service.gradle.kts"),
			Path("./big_project/.gradle"),
			Path("./big_project/.gradle/8.10.2/generated/some-plugin.gradle.kts"),
			Path("./big_project/.gradle/kotlin-dsl/accessors/build.gradle.kts"),
		}, "%.gradle", fake_build_tool_dir_name)

		local modules = project:get_modules()
		local module_names = vim.iter(modules)
			:map(function(m)
				return m.base_dir:to_string()
			end)
			:totable()
		table.sort(module_names)

		local expected = {
			Path("./big_project"):to_string(),
			Path("./big_project/service"):to_string(),
		}
		table.sort(expected)
		eq(expected, module_names)
	end)

	it("accepts custom gradle filenames that contain 'settings.gradle' as substring", function()
		local project = Project.from_dirs_and_project_file({
			Path("./my_project/mysettings.gradle.kts"),
			Path("./my_project/app/appsettings.gradle.kts"),
			Path("./my_project/settings.gradle.kts"),
		}, "%.gradle", fake_build_tool_dir_name)

		local module_names = vim.iter(project:get_modules())
			:map(function(m)
				return m.base_dir:to_string()
			end)
			:totable()
		table.sort(module_names)

		local expected = {
			Path("./my_project"):to_string(),
			Path("./my_project/app"):to_string(),
		}
		table.sort(expected)
		eq(expected, module_names)
	end)

	it("deduplicates modules when multiple build files exist in same directory", function()
		local project = Project.from_dirs_and_project_file({
			Path("./my_project/build.gradle"),
			Path("./my_project/build.gradle.kts"),
			Path("./my_project/service/service.gradle.kts"),
		}, "%.gradle", fake_build_tool_dir_name)

		local module_names = vim.iter(project:get_modules())
			:map(function(m)
				return m.base_dir:to_string()
			end)
			:totable()
		table.sort(module_names)

		local expected = {
			Path("./my_project"):to_string(),
			Path("./my_project/service"):to_string(),
		}
		table.sort(expected)
		eq(expected, module_names)
	end)

	it("find module by filepath", function()
		local project = Project.from_dirs_and_project_file({

			Path("./tests/fixtures/multi-module-demo/pom.xml"),
			Path("./tests/fixtures/multi-module-demo/module-a/pom.xml"),
			Path("./tests/fixtures/multi-module-demo/module-b/pom.xml"),
		}, "pom.xml", fake_build_tool_dir_name)

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
