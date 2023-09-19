local RootFinder = require("neotest-java.core.root_finder")

SpecBuilder = {}

---@param args neotest.RunArgs
---@param project_type string
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function SpecBuilder.build_spec(args, project_type)
	local position = args.tree:data()
	local root = RootFinder.find_root(position.path)
	local relative_path = position.path:sub(#root + 2)
	local test_reference = find_java_reference(relative_path, position.name, project_type)
	local is_integration_test = string.find(position.path, "IT.java", 1, true)

	local command_table = {}
	if project_type == "gradle" then
		command_table = {
			"gradle",
			"clean",
			"test",
			"--tests",
			test_reference,
		}
	elseif project_type == "maven" then
		if is_integration_test then
			command_table = {
				"mvn",
				"clean",
				"verify",
				"-Dtest=" .. test_reference,
			}
		else
			command_table = {
				"mvn",
				"clean",
				"test",
				"-Dtest=" .. test_reference,
			}
		end
	end

	local command = table.concat(command_table, " ")
	-- TODO: add debug logger
	-- print("Running command: " .. command)

	return {
		command = command,
		cwd = root,
		symbol = position.name,
		context = {
			project_type = project_type,
		},
	}
end

function find_java_reference(relative_path, name, project_type)
	local class_package = relative_path:gsub("src/test/java/", ""):gsub("/", "."):gsub(".java", "")

	-- if name contains java, then it's a class
	if string.find(name, ".java", 1, true) then
		return class_package
	end

	if project_type == "gradle" then
		return class_package .. "." .. name
	end

	return class_package .. "#" .. name
end

return SpecBuilder
