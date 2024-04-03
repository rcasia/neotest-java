local root_finder = require("neotest-java.core.root_finder")
local CommandBuilder = require("neotest-java.command.junit_command_builder")
local resolve_qualfied_name = require("neotest-java.util.resolve_qualified_name")

SpecBuilder = {}

---@param args neotest.RunArgs
---@param project_type string
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function SpecBuilder.build_spec(args, project_type, ignore_wrapper, config)
	local command = CommandBuilder:new(config, project_type)
	local position = args.tree:data()
	local root = root_finder.find_root(position.path)
	local absolute_path = position.path

	command:set_test_file(absolute_path)

	local reports_dir = "/tmp/neotest-java/" .. vim.fn.strftime("%d%m%y%H%M%S")
	command:reports_dir(reports_dir)

	if position.type == "dir" then
		for _, child in args.tree:iter() do
			if child.type == "file" then
				command:test_reference(resolve_qualfied_name(child.path), child.name, "dir")
			end
		end

		return {
			command = command:build(),
			cwd = root,
			symbol = position.name,
			context = { report_file = reports_dir .. "/TEST-junit-jupiter.xml" },
		}
	end

	-- TODO: this is a workaround until we handle namespaces properly
	if position.type == "namespace" then
		position = args.tree:parent():data()
	end

	-- note: parameterized tests are not being discovered by the junit standalone, so we run tests per file
	command:test_reference(resolve_qualfied_name(absolute_path), position.name, "file")

	-- TODO: add debug logger
	print(command:build())

	return {
		command = command:build(),
		cwd = root,
		symbol = position.name,
		context = { report_file = reports_dir .. "/TEST-junit-jupiter.xml" },
	}
end

return SpecBuilder
