local Path = require("neotest-java.model.path")

local JUNIT_JAR_FILE_NAME = function(version)
	return "junit-platform-console-standalone-" .. version .. ".jar"
end
local DEFAULT_JUNIT_JAR_PATH = function(version)
	return Path(vim.fn.stdpath("data")):append("neotest-java"):append(JUNIT_JAR_FILE_NAME(version))
end

local SUPPORTED_VERSIONS = {
	{
		version = "6.0.1",
		sha256 = "3009120b7953bfe63add272e65b2bbeca0d41d0dfd8dea605201db15b640e0ff",
	},
	{
		version = "1.10.1",
		sha256 = "b42eaa53d13576d17db5fb8b280722a6ae9e36daf95f4262bc6e96d4cb20725f",
	},
}
local LATEST_PINNED_VERSION = SUPPORTED_VERSIONS[1]

--- Get supported JUnit versions
--- @return table[]
local function get_supported_versions()
	return SUPPORTED_VERSIONS
end

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
---@field disable_update_notifications boolean | nil

---@type neotest-java.ConfigOpts
local default_config = {
	default_junit_jar_filepath = DEFAULT_JUNIT_JAR_PATH(LATEST_PINNED_VERSION.version),
	junit_jar = DEFAULT_JUNIT_JAR_PATH(LATEST_PINNED_VERSION.version),
	default_junit_jar_version = LATEST_PINNED_VERSION,
	jvm_args = {},
	incremental_build = true,
	disable_update_notifications = false,
	test_classname_patterns = {
		"^.*Tests?$",
		"^.*IT$",
		"^.*Spec$",
	},
}

-- Export getter function for supported versions
default_config.get_supported_versions = get_supported_versions

return default_config
