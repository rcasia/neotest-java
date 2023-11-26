local ProjectType = {
	gradle = { name = "gradle", wrapper = "./gradlew", global_binary = "gradle" },
	maven = { name = "maven", wrapper = "./mvnw", global_binary = "mvn" },
}

local MAVEN = ProjectType.maven.name

local function is_integration_test(file_name)
	return file_name:find("IT.java") ~= nil
end

local CommandBuilder = {

	--- @return CommandBuilder
	new = function(self)
		self.__index = self
		return setmetatable({}, self)
	end,

	---@param relative_path string example: src/test/java/com/example/ExampleTest.java
	---@param node_name? string example: shouldNotFail
	---@return CommandBuilder
	test_reference = function(self, relative_path, node_name, type)
		self._test_references = self._test_references or {}

		local method_name
		if type == "test" then
			method_name = node_name
		end

		self._test_references[#self._test_references + 1] = {
			relative_path = relative_path,
			method_name = method_name,
		}

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

	get_referenced_classes = function(self)
		local classes = {}
		for _, v in ipairs(self._test_references) do
			local class_package = self:_create_test_reference(v.relative_path)
			classes[#classes + 1] = class_package
		end
		return classes
	end,

	get_referenced_methods = function(self)
		local methods = {}
		for _, v in ipairs(self._test_references) do
			local method = self:_create_test_reference(v.relative_path, v.method_name)
			methods[#methods + 1] = method
		end
		return methods
	end,

	get_referenced_method_names = function(self)
		local method_names = {}
		for _, v in ipairs(self._test_references) do
			method_names[#method_names + 1] = v.method_name
		end
		return method_names
	end,

	_create_test_reference = function(self, relative_path, method_name)
		local class_package = relative_path:gsub("(.-)src/test/java/", ""):gsub("/", "."):gsub(".java", "")

		if method_name == nil then
			return class_package
		end

		if self._project_type.name == "gradle" then
			return class_package .. "." .. method_name
		end

		return class_package .. "#" .. method_name
	end,

	contains_integration_tests = function(self)
		for _, v in ipairs(self._test_references) do
			if is_integration_test(v.relative_path) then
				return true
			end
		end

		return false
	end,

	--- @return string @command to run
	build = function(self)
		local command = {}

		if self._ignore_wrapper then
			table.insert(command, self._project_type.global_binary)
		else
			table.insert(command, self._project_type.wrapper)
		end

		if MAVEN == self._project_type.name and self:contains_integration_tests() then
			table.insert(command, "verify")
		else
			table.insert(command, "test")
		end

		if self._project_type.name == "gradle" then
			for _, v in ipairs(self._test_references) do
				local test_reference = self:_create_test_reference(v.relative_path, v.method_name)
				if self._project_type.name == "maven" then
					table.insert(command, "-Dtest=" .. test_reference)
				else
					table.insert(command, "--tests " .. test_reference)
				end
			end
		else
			local references = {}
			for _, v in ipairs(self._test_references) do
				local test_reference = self:_create_test_reference(v.relative_path, v.method_name)
				table.insert(references, test_reference)
			end
			table.insert(command, "-Dtest=" .. table.concat(references, ","))
		end

		return table.concat(command, " ")
	end,
}

return CommandBuilder
