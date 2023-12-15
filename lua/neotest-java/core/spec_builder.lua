local root_finder = require("neotest-java.core.root_finder")
local CommandBuilder = require("neotest-java.util.command_builder")

SpecBuilder = {}

---@param args neotest.RunArgs
---@param project_type neotest-java.BuildTool
---@config config neotest-java.Config
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function SpecBuilder.build_spec(args, project_type, config)
	local command = CommandBuilder:new()
	local position = args.tree:data()
	local root = root_finder.find_root(config.buildtools, position.path)
	local relative_path = position.path:sub(#root + 2)

	if position.type == "dir" then
		local test_class_names = {}
		local test_method_names = {}
		for _, child in args.tree:iter() do
			if child.type == "file" then
				local name = child.name
				command:test_reference(child.path, child.name, child.type)

				test_class_names[#test_class_names + 1] = name
			elseif child.type == "test" then
				-- to be able to extract the method_names
				test_method_names[#test_method_names + 1] = child.name
			end
		end

		command:project_type(project_type)
		command:ignore_wrapper(config.ignore_wrapper)

		return {
			command = command:build(),
			cwd = root,
			symbol = position.name,
			context = {
				project_type = project_type,
				test_class_names = command:get_referenced_classes(),
				test_method_names = test_method_names,
			},
		}
	end

	-- TODO: this is a workaround until we handle namespaces properly
	if position.type == "namespace" then
		position = args.tree:parent():data()
	end

	-- TODO: refactor this
	local test_class = relative_path:gsub(project_type.test_src, ""):gsub("/", "."):gsub(".java", ""):gsub("#.*", "")

	command:project_type(project_type)
	command:ignore_wrapper(config.ignore_wrapper)
	command:test_reference(relative_path, position.name, position.type)

	local test_method_names = {}
	if project_type.name == "gradle" then
		if position.type == "file" then
			for i, child in ipairs(args.tree:children()) do
				-- FIXME: this need to check also if the position is a test
				local child_postion = child:data()
				test_method_names[i] = child_postion.name
			end
		else
			test_method_names[1] = position.name
		end
	end

	-- TODO: add debug logger
	-- print("Running command: " .. command)

	return {
		command = command:build(),
		cwd = root,
		symbol = position.name,
		context = {
			project_type = project_type,
			test_class_names = command:get_referenced_classes(),
			test_method_names = test_method_names,
		},
	}
end

return SpecBuilder
