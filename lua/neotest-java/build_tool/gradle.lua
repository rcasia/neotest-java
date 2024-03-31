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

local function run(command)
	local success = os.execute(command)
	assert(success, "error while running command " .. command)
end

---@class neotest-java.BuildTool
local gradle = {}

gradle.get_dependencies_classpath = function()
	-- create dir if not exists
	run("mkdir -p " .. gradle.get_output_dir())

	-- '< /dev/null' is necessary
	-- https://github.com/gradle/gradle/issues/15941#issuecomment-1191510921
	run(
		"gradle dependencies --console plain -p /home/rico/REPOS/reactor-playground > "
			.. "build/neotest-java"
			.. "/dependencies.txt < /dev/null"
	)

	local classpath_output = gradle.get_output_dir() .. "/classpath.txt"
	-- run("echo > " .. classpath_output)
	-- borrar el archivo si existe
	run("rm -f " .. classpath_output)

	local jars = iter(File.read_lines(gradle.get_output_dir() .. "/dependencies.txt"))
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

	iter(jars):foreach(function(jar)
		run("echo -n :" .. jar .. " >> " .. classpath_output)
	end)

	return result
end

gradle.write_classpath = function(classpath_filename)
	gradle.get_dependencies_classpath()
	-- todo
end

gradle.get_output_dir = function()
	return "build/neotest-java"
end

return gradle
