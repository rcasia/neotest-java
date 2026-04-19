local CommandBuilder = require("neotest-java.command.junit_command_builder")
local Path = require("neotest-java.model.path")

describe("JUnitCommandBuilder", function()
	local function base_builder()
		return CommandBuilder.new()
			:java_bin(Path("java"))
			:junit_jar(Path("junit.jar"))
			:basedir(Path("."))
			:classpath_file_arg("classpath-file")
			:spring_property_filepaths({ Path("src/main/resources/application.properties") })
			:reports_dir(Path("reports"))
	end

	it("adds class selector for namespace position", function()
		local tree = {
			data = function()
				return {
					type = "namespace",
					id = "com.example.ExampleTest",
				}
			end,
			iter = function()
				return ipairs({})
			end,
		}

		local command = base_builder():add_test_references_from_tree(tree):build_to_table()

		assert(vim.iter(command.args):any(function(arg)
			return arg == "--select-class='com.example.ExampleTest'"
		end))
	end)

	it("supports iter entries that expose position via :data()", function()
		local tree = {
			data = function()
				return {
					type = "file",
				}
			end,
			iter = function()
				return ipairs({
					{
						data = function()
							return {
								type = "namespace",
								id = "com.example.ExampleTest",
							}
						end,
					},
				})
			end,
		}

		local command = base_builder():add_test_references_from_tree(tree):build_to_table()

		assert(vim.iter(command.args):any(function(arg)
			return arg == "--select-class='com.example.ExampleTest'"
		end))
	end)

	it("always excludes the archunit engine to prevent cross-engine interference", function()
		local tree = {
			data = function()
				return { type = "namespace", id = "com.example.ExampleTest" }
			end,
			iter = function()
				return ipairs({})
			end,
		}

		local command = base_builder():add_test_references_from_tree(tree):build_to_table()

		assert(
			vim.iter(command.args):any(function(arg)
				return arg == "--exclude-engine=archunit"
			end),
			"expected --exclude-engine=archunit in command args"
		)
	end)
end)
