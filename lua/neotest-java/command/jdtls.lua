local runtime = require("neotest-java.command.runtime")
local classpaths = require("neotest-java.command.classpath")

local write_file = require("neotest-java.util.write_file")
local compatible_path = require("neotest-java.util.compatible_path")

local M = {}

M.get_java_home = runtime

M.get_classpath = classpaths

M.get_classpath_file_argument = function(report_dir, additional_classpath_entries)
	local classpath = table.concat(M.get_classpath(additional_classpath_entries), ":")
	local temp_file = compatible_path(report_dir .. "/.cp")
	write_file(temp_file, ("-cp %s"):format(classpath))

	return ("@%s"):format(temp_file)
end

return M
