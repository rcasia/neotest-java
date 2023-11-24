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

	test_reference = function(self, relative_path, node_name, node_type)
		self._relative_path = relative_path
		if node_type == "test" then
			self._method_name = node_name
		end

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

	_create_test_reference = function(self)
		local class_package = self._relative_path:gsub("src/test/java/", ""):gsub("/", "."):gsub(".java", "")

		if self._method_name == nil then
			return class_package
		end

		if self._project_type.name == "gradle" then
			return class_package .. "." .. self._method_name
		end

		return class_package .. "#" .. self._method_name
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

		local test_reference = self:_create_test_reference()
		if self._project_type.name == "maven" then
			table.insert(command, "-Dtest=" .. test_reference)
		else
			table.insert(command, "--tests " .. test_reference)
		end

		return table.concat(command, " ")
	end,
}

SpecBuilder = {}

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

	-- TODO: refactor this
	local test_class = relative_path:gsub("src/test/java/", ""):gsub("/", "."):gsub(".java", ""):gsub("#.*", "")

	-- TODO: find a better way to detect integration tests
	local is_integration_test = string.find(position.path, "IT.java", 1, true)

	command:project_type(project_type)
	command:ignore_wrapper(ignore_wrapper)
	command:is_integration_test(is_integration_test)
	command:test_reference(relative_path, position.name, position.type)

	local test_method_names = {}
	if project_type == ProjectType.gradle.name then
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
			test_class_path = test_class,
			test_method_names = test_method_names,
		},
	}
end

return SpecBuilder
