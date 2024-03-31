local fun = require("fun")
local iter = fun.iter
local totable = fun.totable
local scan = require("plenary.scandir")
local File = require("neotest.lib.file")

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
	local dir = string.format("/home/rico/.gradle/caches/modules-2/files-2.1/%s/%s/%s", group_id, artifact_id, version)
	local result = find_file_in_dir(filename, dir)
	return result
end

local function take_just_the_dependency(line)
	local dependency = line:match("[%w.-]+:[%w.-]+:[%w.-]+")
	local old_version, new_version = line:match("(%d+%.%d+%.%d+) %-+> (%d+%.%d+%.%d+)")

	if dependency and new_version then
		return string.gsub(dependency, old_version, new_version)
	end

	return dependency
end

local function remove_duplicates(t)
	local seen = {}
	local result = {}

	for _, value in ipairs(t) do
		if not seen[value] then
			table.insert(result, value)
			seen[value] = true
		end
	end

	return result
end

local function run(command)
	-- io.popen(command)
	os.execute(command)
end

---@class neotest-java.BuildTool
local gradle = {}

---@return string
gradle.get_dependencies_classpath = function()
	local dependencies_output = "/tmp/dependencies.txt"
	run("gradle dependencies -p /home/rico/REPOS/reactor-playground >> " .. dependencies_output)

	local classpath_output = "/tmp/classpath.txt"
	run("echo > " .. classpath_output)
	local jars = iter(File.read_lines(dependencies_output))
		--
		:map(take_just_the_dependency)
		--
		:map(to_gradle_path)
		--
		:filter(function(x)
			return x ~= nil
		end)
		--
		:map(function(x)
			print(x)
			return x
		end)
		-- distinct
		:reduce(function(acc, curr)
			if not acc[curr] then
				acc[curr] = curr
			end
			return acc
		end, {})

	iter(jars):foreach(function(jar)
		print(jar)
		run("echo -n :" .. jar .. " >> " .. classpath_output)
	end)

	return result
end

return gradle
