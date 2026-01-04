local Path = require("neotest-java.model.path")

local DEFAULT_VERSION = "1.10.1"
local JUNIT_JAR_FILE_NAME = "junit-platform-console-standalone-" .. DEFAULT_VERSION .. ".jar"

---@class neotest-java.ConfigOpts
---@field junit_jar neotest-java.Path
---@field jvm_args string[]
---@field incremental_build boolean
---@field default_version string
---@field test_classname_patterns string[] | nil

---@type neotest-java.ConfigOpts
local default_config = {
	junit_jar = Path(vim.fn.stdpath("data")):append("neotest-java"):append(JUNIT_JAR_FILE_NAME),
	jvm_args = {},
	incremental_build = true,
	default_version = DEFAULT_VERSION,
	test_classname_patterns = {
		"^.*Tests?$",
		"^.*IT$",
		"^.*Spec$",
	},
}

return default_config
