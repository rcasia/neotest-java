local RootFinder = require("neotest-java.core.root_finder")

local CommandBuilder = {
	_executable = "",

	--- @return CommandBuilder
	new = function(self)
		self.__index = self
		return setmetatable({}, self)
	end,

	--- @param executable string @executable bashunit executable binary
	executable = function(self, executable)
		self._executable = executable
		return self
	end,

	is_integration_test = function(self, is_integration_test)
		self._is_integration_test = is_integration_test
		return self
	end,

	test_reference = function(self, test_reference)
		self._test_reference = test_reference
		return self
	end,

	project_type = function(self, project_type)
		self._project_type = project_type
		return self
	end,

	--- @return string @command to run
	build = function(self)
		local command = {}

		table.insert(command, self._executable)

		if self._is_integration_test then
			table.insert(command, "verify")
		else
			table.insert(command, "test")
		end

		if self._test_reference and self._project_type ~= "gradle" then
			table.insert(command, "-Dtest=" .. self._test_reference)
		elseif self._test_reference and self._project_type == "gradle" then
			table.insert(command, "--tests " .. self._test_reference)
		end

		return table.concat(command, " ")
	end,
}

SpecBuilder = {}

-- TODO: refactor everything here
local function find_java_reference(relative_path, name, project_type)
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

---@param args neotest.RunArgs
---@param project_type string
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function SpecBuilder.build_spec(args, project_type, ignore_wrapper)
	local command = CommandBuilder:new()
	local position = args.tree:data()

	-- TODO: this is a workaround until we handle namespaces properly
	if position.type == "namespace" then
		position = args.tree:parent():data()
	end

	local root = RootFinder.find_root(position.path)
	local relative_path = position.path:sub(#root + 2)
	local test_reference = find_java_reference(relative_path, position.name, project_type)
	local is_integration_test = string.find(position.path, "IT.java", 1, true)

	local test_class_path = string.gsub(test_reference, "#.*", "")

	local command_table = {}
	local test_method_names = {}
	if project_type == "gradle" then
		local executable = ignore_wrapper and "gradle" or "./gradlew"

		command:executable(executable)
		command:project_type(project_type)
		command:test_reference(test_reference)

		if position.type == "file" then
			local children = args.tree:children()

			for i, child in ipairs(children) do
				local child_postion = child:data()
				test_method_names[i] = child_postion.name
			end
		else
			test_method_names[1] = position.name
			-- com.example.ExampleTest.firstTest -> com.example.ExampleTest
			test_class_path = string.gsub(test_class_path, "%.[^%.]*$", "")
		end
	elseif project_type == "maven" then
		local executable = ignore_wrapper and "mvn" or "./mvnw"

		command:executable(executable)
		command:is_integration_test(is_integration_test)
		command:test_reference(test_reference)
	end

	-- TODO: add debug logger
	-- print("Running command: " .. command)

	return {
		command = command:build(),
		cwd = root,
		symbol = position.name,
		context = {
			project_type = project_type,
			test_class_path = test_class_path,
			test_method_names = test_method_names,
		},
	}
end

return SpecBuilder
