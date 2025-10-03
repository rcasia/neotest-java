local binaries = require("neotest-java.command.binaries")
local java = binaries.java
local logger = require("neotest-java.logger")

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
			method_name = qualified_name
		end

		self._test_references[#self._test_references + 1] = {
			qualified_name = qualified_name,
			method_name = method_name,
			type = type,
		}

		return self
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

	_create_method_qualified_reference = function(_, qualified_name, method_name)
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

	reports_dir = function(self, reports_dir)
		self._reports_dir = reports_dir
	end,

	basedir = function(self, basedir)
		logger.debug("assigned basedir: " .. basedir)
		self._basedir = basedir
	end,

	classpath_file_arg = function(self, classpath_file_arg)
		self._classpath_file_arg = classpath_file_arg
	end,

	--- @param property_filepaths string[]
	spring_property_filepaths = function(self, property_filepaths)
		self._spring_property_filepaths = property_filepaths
	end,

	--- @param port? number
	--- @return { command: string, args: string[] }
	build_junit = function(self, port)
		assert(self._test_references, "test_references cannot be nil")
		assert(self._basedir, "basedir cannot be nil")
		assert(self._classpath_file_arg, "classpath_file_arg cannot be nil")
		assert(self._spring_property_filepaths, "_spring_property_filepaths cannot be nil")

		local selectors = {}
		for _, v in ipairs(self._test_references) do
			if v.type == "test" then
				table.insert(selectors, "-m=" .. v.qualified_name)
			elseif v.type == "file" then
				table.insert(selectors, "-c=" .. v.qualified_name)
			elseif v.type == "dir" then
				selectors = "-p=" .. v.qualified_name
			end
		end
		assert(#selectors ~= 0, "junit command has to have a selector")

		local junit_command = {
			command = java(),
			args = {
				"-Dspring.config.additional-location=" .. table.concat(self._spring_property_filepaths, ","),
				"-jar",
				self._junit_jar,
				"execute",
				("%s"):format(self._classpath_file_arg),
				"--reports-dir=" .. self._reports_dir,
				"--fail-if-no-tests",
				"--disable-banner",
				"--details=testfeed",
				"--config=junit.platform.output.capture.stdout=true",
			},
		}
		-- add selectors
		for _, v in ipairs(selectors) do
			table.insert(junit_command.args, v)
		end

		-- add debug arguments if debug port is specified
		if port then
			table.insert(junit_command.args, 1, "-Xdebug")
			table.insert(
				junit_command.args,
				1,
				"-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=0.0.0.0:" .. port
			)
		end

		return junit_command
	end,

	--- @param port? number
	--- @return { command: string, args: string[] }
	build_to_string = function(self, port)
		local c = self:build_junit(port)
		return c.command .. " " .. table.concat(c.args, " ")
	end,
}

return CommandBuilder
