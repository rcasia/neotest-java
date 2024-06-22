local fun = require("fun")
local iter = fun.iter
local totable = fun.totable
local scan = require("plenary.scandir")
local File = require("neotest.lib.file")
local run = require("neotest-java.command.run")
local binaries = require("neotest-java.command.binaries")

local JAVA_FILE_PATTERN = ".+%.java$"

local function find_file_in_dir(filename, dir)
	return totable(
		--
		iter(scan.scan_dir(dir, { silent = true }))
			--
			:filter(function(path)
				return string.find(path, filename, 1, true)
			end)
	)[1]
end

local function to_gradle_path(dependency)
	if dependency == nil then
		return nil
	end
	local group_id, artifact_id, version = dependency:match("([^:]+):([^:]+):([^:]+)")

	local filename = string.format("%s-%s.jar", artifact_id, version)
	local dir = string.format(
		"%s/.gradle/caches/modules-2/files-2.1/%s/%s/%s",
		os.getenv("HOME"),
		group_id,
		artifact_id,
		version
	)
	local result = find_file_in_dir(filename, dir)
	return result
end

local function take_just_the_dependency(line)
	--
	-- Example of line with a standard dependency line
	-- | +--- org.springframework.boot:spring-boot-starter:3.1.0
	-- Expected:
	-- org.springframework.boot:spring-boot-starter:3.1.0", dependency1)

	-- Example of line with a dependency line that shows a version update
	-- | +--- org.junit.platform:junit-platform-launcher:1.9.2 -> 1.9.3
	-- Expected:
	-- org.junit.platform:junit-platform-launcher:1.9.3
	--
	local dependency = line:match("[%w.-]+:[%w.-]+:[%w.-]+")
	local old_version, new_version = line:match("(%d+%.%d+%.%d+) %-+> (%d+%.%d+%.%d+)")

	if dependency and new_version then
		return string.gsub(dependency, old_version, new_version)
	end

	return dependency
end

local gradle = {}

gradle.source_dir = function()
	return "src/main/java"
end

gradle.get_output_dir = function()
	return "build/neotest-java"
end

gradle.get_sources = function()
	local sources = scan.scan_dir(gradle.source_dir(), {
		search_pattern = JAVA_FILE_PATTERN,
	})

	local generated_sources = scan.scan_dir("build", {
		search_pattern = JAVA_FILE_PATTERN,
	})

	for _, source in ipairs(generated_sources) do
		table.insert(sources, source)
	end

	return sources
end

gradle.get_test_sources = function()
	local test_sources = scan.scan_dir("src/test/java", {
		search_pattern = JAVA_FILE_PATTERN,
	})
	return test_sources
end

gradle.get_resources = function()
	return { "src/main/resources", "src/test/resources" }
end

gradle.get_dependencies_classpath = function()
	-- create dir if not exists
	run("mkdir -p " .. gradle.get_output_dir())

	-- '< /dev/null' is necessary
	-- https://github.com/gradle/gradle/issues/15941#issuecomment-1191510921
	local suc =
		os.execute(binaries.gradle() .. " dependencies > build/neotest-java" .. "/dependencies.txt " .. "< /dev/null")
	assert(suc, "failed to run")

	local output = run("cat " .. gradle.get_output_dir() .. "/dependencies.txt")
	local output_lines = vim.split(output, "\n")

	local jars = iter(output_lines)
		--
		:map(take_just_the_dependency)
		--
		:map(to_gradle_path)
		--
		-- filter nil
		:filter(function(x)
			return x ~= nil
		end)
		-- distinct
		:reduce(function(acc, curr)
			if not acc[curr] then
				acc[curr] = curr
			end
			return acc
		end, {})

	local result = ""
	iter(jars):foreach(function(jar)
		result = result .. ":" .. jar
	end)

	return result
end

gradle.prepare_classpath = function()
	local classpath = gradle.get_dependencies_classpath()
	local classpath_arguments = ([[
		-cp %s:%s:%s
	]]):format(table.concat(gradle.get_resources(), ":"), classpath, gradle.get_output_dir() .. "/classes")

	--write manifest file
	local arguments_filepath = "build/neotest-java/cp_arguments.txt"
	local arguments_file = io.open(arguments_filepath, "w")
		or error("Could not open file for writing: " .. arguments_filepath)
	local buffer = ""
	for i = 1, #classpath_arguments do
		buffer = buffer .. classpath_arguments:sub(i, i)
		if i % 500 == 0 then
			arguments_file:write(buffer)
			buffer = ""
		end
	end
	if buffer ~= "" then
		arguments_file:write(buffer)
	end

	arguments_file:close()
end

---@type neotest-java.BuildTool
return gradle
