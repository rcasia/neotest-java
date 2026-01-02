local binaries = require("neotest-java.command.binaries")
local java = binaries.java

--- @class neotest-java.TestReference
--- @field qualified_name string
--- @field method_name string?
--- @field type "test" | "file" | "dir"

--- @class CommandBuilder
--- @field _junit_jar neotest-java.Path
--- @field _jvm_args string[]
--- @field _reports_dir neotest-java.Path
--- @field _test_references neotest-java.TestReference
--- @field _basedir neotest-java.Path
--- @field _classpath_file_arg string
--- @field _spring_property_filepaths neotest-java.Path[]
local CommandBuilder = {}
CommandBuilder.__index = CommandBuilder

--- @param junit_jar neotest-java.Path
--- @param jvm_args? string[]
--- @return CommandBuilder
function CommandBuilder.new(junit_jar, jvm_args)
	local fields = {
		_jvm_args = jvm_args or {},
		_junit_jar = junit_jar,
		_test_references = {},
	}
	return setmetatable(fields, CommandBuilder)
end

function CommandBuilder:add_test_method(qualified_name)
	self._test_references[#self._test_references + 1] = {
		qualified_name = qualified_name,
		method_name = qualified_name,
		type = "test",
	}
	return self
end

--- @param self CommandBuilder
--- @param reports_dir neotest-java.Path
function CommandBuilder:reports_dir(reports_dir)
	self._reports_dir = reports_dir
	return self
end

function CommandBuilder:basedir(basedir)
	self._basedir = basedir
	return self
end

function CommandBuilder:classpath_file_arg(classpath_file_arg)
	self._classpath_file_arg = classpath_file_arg
	return self
end

--- @param property_filepaths neotest-java.Path[]
function CommandBuilder:spring_property_filepaths(property_filepaths)
	self._spring_property_filepaths = property_filepaths
	return self
end

--- @param self CommandBuilder
--- @param port? number
--- @return { command: string, args: string[] }
CommandBuilder.build_junit = function(self, port)
	assert(self._test_references, "test_references cannot be nil")
	assert(self._basedir, "basedir cannot be nil")
	assert(self._classpath_file_arg, "classpath_file_arg cannot be nil")
	assert(self._spring_property_filepaths, "_spring_property_filepaths cannot be nil")

	local selectors = {}
	for _, v in ipairs(self._test_references) do
		if v.type == "test" then
			local class_name = v.qualified_name:match("^(.-)#") or v.qualified_name
			if v.method_name then
				table.insert(selectors, "--select-method=" .. v.method_name)
			else
				table.insert(selectors, "--select-class=" .. class_name)
			end
		end
	end
	assert(#selectors ~= 0, "junit command has to have a selector")

	local additional_location_arg = vim
		.iter(self._spring_property_filepaths)
		--- @param path neotest-java.Path
		:map(function(path)
			return path:to_string()
		end)
		:join(",")

	local jvm_args = {
		"-Dspring.config.additional-location=" .. additional_location_arg,
		unpack(self._jvm_args),
	}

	local junit_command = {
		command = java(),
		args = vim.iter({
			jvm_args,
			"-jar",
			self._junit_jar:to_string(),
			"execute",
			"--classpath=" .. self._classpath_file_arg,
			"--reports-dir=" .. self._reports_dir:to_string(),
			"--fail-if-no-tests",
			"--disable-banner",
			"--details=testfeed",
			"--config=junit.platform.output.capture.stdout=true",
		})
			:flatten()
			:totable(),
	}
	-- add selectors
	for _, v in ipairs(selectors) do
		table.insert(junit_command.args, v)
	end

	if self._basedir then
		table.insert(junit_command.args, 1, "-Duser.dir=" .. self._basedir)
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
end

--- @param port? number
--- @return string
CommandBuilder.build_to_string = function(self, port)
	local c = self:build_junit(port)
	return c.command .. " " .. table.concat(c.args, " ")
end

return CommandBuilder
