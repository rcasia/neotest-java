local Path = require("neotest-java.model.path")

local DEFAULT_CONFIG = require("neotest-java.default_config")

--- @param file_path neotest-java.Path
--- @param file_reader? fun(path: string): string
--- @return string hash
local function checksum(file_path, file_reader)
	file_reader = file_reader
		or function(path)
			local f = assert(io.open(path, "rb"))
			local data = f:read("*a")
			f:close()
			return data
		end
	local data = file_reader(file_path:to_string())
	local hash = vim.fn.sha256(data)
	return hash
end

--- Get supported versions from default_config
--- @return table[]
local function get_supported_versions()
	return DEFAULT_CONFIG.get_supported_versions()
end

---@class neotest-java.JunitVersionDetectorDeps
---@field exists fun(filepath: neotest-java.Path): boolean
---@field checksum fun(file_path: neotest-java.Path): string
---@field scan fun(dir: neotest-java.Path, opts: { search_patterns: string[] }): neotest-java.Path[]
---@field stdpath_data fun(): string

---@class neotest-java.JunitVersionDetector
---@field detect_existing_version fun(): neotest-java.JunitVersion | nil, neotest-java.Path | nil
---@field check_for_update fun(current_version: neotest-java.JunitVersion): boolean, neotest-java.JunitVersion | nil
---@field get_supported_versions fun(): table[]
---@field _checksum fun(file_path: neotest-java.Path, file_reader?: fun(path: string): string): string

--- @param deps neotest-java.JunitVersionDetectorDeps
--- @return neotest-java.JunitVersionDetector
local JunitVersionDetector = function(deps)
	local exists_fn = deps.exists
	local checksum_fn = deps.checksum
	local scan_fn = deps.scan
	local stdpath_data_fn = deps.stdpath_data

	return {
		--- Detect which version of JUnit jar exists in the data directory
		--- @return neotest-java.JunitVersion | nil, neotest-java.Path | nil
		-- Returns: version_info, filepath
		detect_existing_version = function()
			local supported_versions = get_supported_versions()
			local data_dir = Path(stdpath_data_fn("data")):append("neotest-java")

			-- First, try to detect by filename
			for _, version_info in ipairs(supported_versions) do
				local jar_path = data_dir:append("junit-platform-console-standalone-" .. version_info.version .. ".jar")
				if exists_fn(jar_path) then
					-- Verify by checksum to be sure
					local file_sha = checksum_fn(jar_path)
					if file_sha == version_info.sha256 then
						return version_info, jar_path
					end
				end
			end

			-- If not found by filename, try to detect by checksum
			-- This handles cases where the file might have a different name
			local ok, jar_files = pcall(function()
				return scan_fn(data_dir, { search_patterns = { "junit-platform-console-standalone-.*%.jar" } })
			end)

			if ok and jar_files then
				for _, jar_file in ipairs(jar_files) do
					-- jar_file is a Path object
					local file_sha = checksum_fn(jar_file)
					for _, version_info in ipairs(supported_versions) do
						if file_sha == version_info.sha256 then
							return version_info, jar_file
						end
					end
				end
			end

			return nil, nil
		end,

		--- Check if there's a newer version available than the one currently installed
		--- @param current_version neotest-java.JunitVersion
		--- @return boolean, neotest-java.JunitVersion | nil
		-- Returns: has_update, latest_version
		check_for_update = function(current_version)
			local supported_versions = get_supported_versions()
			local latest_version = supported_versions[1] -- First is always latest

			if current_version.version ~= latest_version.version then
				return true, latest_version
			end

			return false, nil
		end,

		--- Get supported versions from default_config
		--- @return table[]
		get_supported_versions = get_supported_versions,

		--- @param file_path neotest-java.Path
		--- @param file_reader? fun(path: string): string
		--- @return string hash
		_checksum = checksum, -- Exposed for testing
	}
end

return JunitVersionDetector
