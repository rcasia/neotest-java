local RootFinder = require("neotest-java.core.root_finder")

local ProjectType = {
	gradle = { name = "gradle", wrapper = "./gradlew", global_binary = "gradle" },
	maven = { name = "maven", wrapper = "./mvnw", global_binary = "mvn" },
}

local CommandBuilder = {

	--- @return CommandBuilder
	new = function(self)
		self.__index = self
		return setmetatable({}, self)
	end,

	is_integration_test = function(self, is_integration_test)
		self._is_integration_test = is_integration_test
		return self
	end,

	test_reference = function(self, test_reference)
		self._test_reference = test_reference
		return self
	end,

	--- @param project_type string @project_type maven | gradle
	project_type = function(self, project_type)
		if ProjectType[project_type] == nil then
			error(string.format("expected '%s' to be maven or gradle", project_type))
		end
		self._project_type = ProjectType[project_type]
		return self
	end,

	ignore_wrapper = function(self, ignore_wrapper)
		self._ignore_wrapper = ignore_wrapper
		return self
	end,

	--- @return string @command to run
	build = function(self)
		local command = {}

		if self._ignore_wrapper then
			table.insert(command, self._project_type.global_binary)
		else
			table.insert(command, self._project_type.wrapper)
		end

		if self._is_integration_test then
			table.insert(command, "verify")
		else
			table.insert(command, "test")
		end

		if self._project_type.name == "maven" then
			table.insert(command, "-Dtest=" .. self._test_reference)
		else
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

	command:project_type(project_type)
	command:ignore_wrapper(ignore_wrapper)
	command:test_reference(test_reference)
	command:is_integration_test(is_integration_test)
	command:test_reference(test_reference)

	local test_method_names = {}
	if project_type == "gradle" then
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
