local RootFinder = require("neotest-java.core.root_finder")

SpecBuilder = {}

---@param args neotest.RunArgs
---@param project_type string
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function SpecBuilder.build_spec(args, project_type, ignore_wrapper)
	local position = args.tree:data()
	local root = RootFinder.find_root(position.path)
	local relative_path = position.path:sub(#root + 2)
	local test_reference = find_java_reference(relative_path, position.name, project_type)
	local is_integration_test = string.find(position.path, "IT.java", 1, true)
	local is_file = string.find(position.name, ".java", 1, true)

	local test_class_path = string.gsub(test_reference, "#.*", "")

	local test_method_names = {}
	if project_type == "gradle" then
		local executable = ignore_wrapper and "gradle" or "./gradlew"
		command_table = {
			executable,
			"test",
			"--tests",
			test_reference,
		}

		if is_file then
			local children = args.tree:children()

			for i, child in ipairs(children) do
				child_postion = child:data()
				test_method_names[i] = child_postion.name
			end
		else
			test_method_names[1] = position.name
			-- com.example.ExampleTest.firstTest -> com.example.ExampleTest
			test_class_path = string.gsub(test_class_path, "%.[^%.]*$", "")
		end
	elseif project_type == "maven" then
		local executable = ignore_wrapper and "mvn" or "./mvnw"
		if is_integration_test then
			command_table = {
				executable,
				"verify",
				"-Dtest=" .. test_reference,
			}
		else
			command_table = {
				executable,
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
			test_class_path = test_class_path,
			test_method_names = test_method_names,
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
