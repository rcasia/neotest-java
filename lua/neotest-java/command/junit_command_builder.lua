local maven = require("neotest-java.build_tool.maven")
local gradle = require("neotest-java.build_tool.gradle")
local build_tools = require("neotest-java.build_tool")

--- @class CommandBuilder
local CommandBuilder = {

	--- @return CommandBuilder
	new = function(self, config, project_type)
		self.__index = self
		self._junit_jar = config.junit_jar
		self._project_type = project_type
		return setmetatable({}, self)
	end,

	---@param qualified_name string example: com.example.ExampleTest
	---@param node_name? string example: shouldNotFail
	---@return CommandBuilder
	test_reference = function(self, qualified_name, node_name, type)
		self._test_references = self._test_references or {}

		if type == "dir" then
			qualified_name = qualified_name:match("(.+)%..+")
		end

		local method_name
		if type == "test" then
			method_name = node_name
		end

		self._test_references[#self._test_references + 1] = {
			qualified_name = qualified_name,
			method_name = method_name,
			type = type,
		}

		return self
	end,

	ignore_wrapper = function(self, ignore_wrapper)
		-- do nothing
	end,

	get_referenced_classes = function(self)
		local classes = {}
		for _, v in ipairs(self._test_references) do
			local class_package = self:_create_method_qualified_reference(v.qualified_name)
			classes[#classes + 1] = class_package
		end
		return classes
	end,

	get_referenced_methods = function(self)
		local methods = {}
		for _, v in ipairs(self._test_references) do
			local method = self:_create_method_qualified_reference(v.qualified_name, v.method_name)
			methods[#methods + 1] = method
		end
		return methods
	end,

	_create_method_qualified_reference = function(self, qualified_name, method_name)
		if method_name == nil then
			return qualified_name
		end

		return qualified_name .. "#" .. method_name
	end,
	get_referenced_method_names = function(self)
		local method_names = {}
		for _, v in ipairs(self._test_references) do
			method_names[#method_names + 1] = v.method_name
		end
		return method_names
	end,

	set_test_file = function(self, test_file)
		self._test_file = test_file
	end,

	reports_dir = function(self, reports_dir)
		self._reports_dir = reports_dir
	end,

	--- @return string @command to run
	build = function(self)
		local build_tool = build_tools.get(self._project_type)
		local build_dir = build_tool.get_output_dir()
		local output_dir = build_dir .. "/classes"
		local classpath_filename = build_dir .. "/classpath.txt"
		local reference = self._test_references[1]

		local ref
		if reference.type == "test" then
			ref = "-m=" .. reference.qualified_name .. "#" .. reference.method_name
		elseif reference.type == "file" then
			ref = "-c=" .. reference.qualified_name
		elseif reference.type == "dir" then
			ref = "-p=" .. reference.qualified_name
		end
		assert(ref, "ref is nil")

		build_tool.write_classpath(classpath_filename)

		local command = {
			"javac",
			"-d " .. output_dir,
			string.format("-cp $(cat %s)", classpath_filename),
			"src/main/**/*.java",
			"&&",
			"javac",
			"-d " .. output_dir,
			string.format("-cp $(cat %s):%s", classpath_filename, output_dir),
			"src/test/**/*.java",
			"&&",
			"java",
			"-jar " .. self._junit_jar,
			"execute",
			string.format("-cp $(cat %s):%s", classpath_filename, output_dir),
			ref,
			"--fail-if-no-tests",
			"--reports-dir=" .. self._reports_dir,
		}

		local command_string = table.concat(command, " ")

		return command_string
	end,
}

return CommandBuilder
