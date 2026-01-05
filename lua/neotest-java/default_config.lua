local Path = require("neotest-java.model.path")

local DEFAULT_VERSION = "1.10.1"
local JUNIT_JAR_FILE_NAME = "junit-platform-console-standalone-" .. DEFAULT_VERSION .. ".jar"
local DEFAULT_JUNIT_JAR_PATH = Path(vim.fn.stdpath("data")):append("neotest-java"):append(JUNIT_JAR_FILE_NAME)

--- @class neotest-java.JunitVersion
--- @field version string
--- @field sha256 string

---@class neotest-java.ConfigOpts
---@field default_junit_jar_filepath neotest-java.Path
---@field junit_jar neotest-java.Path
---@field jvm_args string[]
---@field incremental_build boolean
---@field default_junit_jar_version neotest-java.JunitVersion
---@field test_classname_patterns string[] | nil

---@type neotest-java.ConfigOpts
local default_config = {
	default_junit_jar_filepath = DEFAULT_JUNIT_JAR_PATH,
	junit_jar = DEFAULT_JUNIT_JAR_PATH,
	jvm_args = {},
	incremental_build = true,
	default_junit_jar_version = {
		version = DEFAULT_VERSION,
		sha256 = "b42eaa53d13576d17db5fb8b280722a6ae9e36daf95f4262bc6e96d4cb20725f",
	},
	test_classname_patterns = {
		"^.*Tests?$",
		"^.*IT$",
		"^.*Spec$",
	},
}

return default_config
