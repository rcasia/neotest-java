#!/usr/bin/env -S nvim -l
-- E2E test for neotest-java
-- Runs real tests through Neotest and verifies results

local uv = vim.loop

-- ANSI color codes
local colors = {
	green = "\27[0;32m",
	red = "\27[0;31m",
	yellow = "\27[1;33m",
	blue = "\27[0;34m",
	reset = "\27[0m",
}

local function log(color, msg)
	io.write(color .. msg .. colors.reset .. "\n")
	io.flush()
end

local function log_section(msg)
	log(colors.blue, "=== " .. msg .. " ===\n")
end

local function log_success(msg)
	log(colors.green, "✓ " .. msg)
end

local function log_error(msg)
	log(colors.red, "✗ " .. msg)
end

local function log_info(msg)
	log(colors.yellow, msg)
end

local function execute(cmd, cwd)
	local handle = io.popen((cwd and ("cd " .. vim.fn.shellescape(cwd) .. " && ") or "") .. cmd .. " 2>&1")
	if not handle then
		return nil, "Failed to execute command"
	end
	local result = handle:read("*a")
	local success = handle:close()
	return result, success
end

local function file_exists(path)
	local stat = uv.fs_stat(path)
	return stat ~= nil and stat.type == "file"
end

local function read_file(path)
	local fd = uv.fs_open(path, "r", 438)
	if not fd then
		return nil
	end
	local stat = uv.fs_fstat(fd)
	if not stat then
		uv.fs_close(fd)
		return nil
	end
	local data = uv.fs_read(fd, stat.size, 0)
	uv.fs_close(fd)
	return data
end

local function write_file(path, content)
	local fd = uv.fs_open(path, "w", 438)
	if not fd then
		return false
	end
	uv.fs_write(fd, content, 0)
	uv.fs_close(fd)
	return true
end

local function download_file(url, output_path)
	local cmd = "curl"
	local has_curl = execute("command -v curl") ~= ""
	local has_wget = execute("command -v wget") ~= ""

	if has_curl then
		return execute(string.format("curl -fsSL -o %s %s", vim.fn.shellescape(output_path), vim.fn.shellescape(url)))
	elseif has_wget then
		return execute(string.format("wget -q -O %s %s", vim.fn.shellescape(output_path), vim.fn.shellescape(url)))
	else
		return nil, "Neither curl nor wget found"
	end
end

local function checksum_sha256(path)
	local has_sha256sum = execute("command -v sha256sum") ~= ""
	local has_shasum = execute("command -v shasum") ~= ""

	if has_sha256sum then
		local result = execute(string.format("sha256sum %s", vim.fn.shellescape(path)))
		return result and result:match("^(%x+)")
	elseif has_shasum then
		local result = execute(string.format("shasum -a 256 %s", vim.fn.shellescape(path)))
		return result and result:match("^(%x+)")
	else
		return nil
	end
end

local function mkdir_p(path)
	execute("mkdir -p " .. vim.fn.shellescape(path))
end

local function compare_json_files(file1, file2)
	local has_jq = execute("command -v jq") ~= ""

	if has_jq then
		local result1 = execute(string.format("jq -S . %s", vim.fn.shellescape(file1)))
		local result2 = execute(string.format("jq -S . %s", vim.fn.shellescape(file2)))
		return result1 == result2, result1, result2
	else
		-- Fallback: compare files directly
		local content1 = read_file(file1)
		local content2 = read_file(file2)
		return content1 == content2, content1, content2
	end
end

-- Main E2E test function
local function main()
	log_section("Neotest-Java E2E Test")

	local proj_root = uv.cwd()
	local fixture_dir = proj_root .. "/tests/fixtures/maven-simple"
	local test_file = fixture_dir .. "/src/test/java/com/example/SampleTest.java"
	local mvnw = fixture_dir .. "/mvnw"

	-- Check prerequisites
	if not file_exists(mvnw) then
		log_error("Maven wrapper not found at " .. mvnw)
		log_info("Please run: cd tests/fixtures/maven-simple && mvn wrapper:wrapper")
		os.exit(1)
	end

	local java_home = os.getenv("JAVA_HOME")
	if not java_home or java_home == "" then
		log_error("JAVA_HOME not set")
		os.exit(1)
	end

	-- Download JUnit JAR if needed
	local junit_version = "6.0.3"
	local junit_jar_name = "junit-platform-console-standalone-" .. junit_version .. ".jar"
	local junit_jar_dir = os.getenv("HOME") .. "/.local/share/nvim/neotest-java"
	local junit_jar_path = junit_jar_dir .. "/" .. junit_jar_name
	local junit_url = string.format(
		"https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/%s/%s",
		junit_version,
		junit_jar_name
	)
	local junit_sha256 = "3ba0d6150af79214a1411f9ea2fbef864eef68b68c89a17f672c0b89bff9d3a2"

	if not file_exists(junit_jar_path) then
		log_info("Downloading JUnit Platform Console Standalone JAR...")
		mkdir_p(junit_jar_dir)

		local result, err = download_file(junit_url, junit_jar_path)
		if not result then
			log_error("Failed to download JUnit JAR: " .. (err or "unknown error"))
			os.exit(1)
		end

		-- Verify checksum
		local actual_sha256 = checksum_sha256(junit_jar_path)
		if actual_sha256 then
			if actual_sha256 ~= junit_sha256 then
				log_error("Checksum verification failed")
				print("Expected: " .. junit_sha256)
				print("Got:      " .. actual_sha256)
				os.remove(junit_jar_path)
				os.exit(1)
			end
			log_success("JUnit JAR downloaded and verified")
		else
			log_info("⚠ No checksum tool found. Skipping verification.")
		end
	else
		log_success("JUnit JAR already present")
	end

	-- Compile test project
	log_info("Compiling test project...")
	local compile_result = execute(mvnw .. " clean test-compile -q", fixture_dir)
	if not compile_result then
		log_error("Compilation failed")
		print("Maven wrapper: " .. mvnw)
		print("Trying with verbose output:")
		execute(mvnw .. " clean test-compile", fixture_dir)
		os.exit(1)
	end
	log_success("Compiled")

	-- Resolve classpath
	log_info("Resolving classpath...")
	local classpath_file = "/tmp/maven-classpath.txt"
	local classpath_result = execute(
		string.format("%s dependency:build-classpath -Dmdep.outputFile=%s -q", mvnw, classpath_file),
		fixture_dir
	)
	if not classpath_result then
		log_error("Classpath resolution failed")
		execute(string.format("%s dependency:build-classpath -Dmdep.outputFile=%s", mvnw, classpath_file), fixture_dir)
		os.exit(1)
	end
	log_success("Classpath resolved")

	-- Read classpath and build full classpath
	local maven_cp = read_file(classpath_file)
	if not maven_cp then
		log_error("Failed to read classpath file")
		os.exit(1)
	end
	maven_cp = maven_cp:gsub("\n", "")

	local full_cp = string.format("%s/target/classes:%s/target/test-classes:%s", fixture_dir, fixture_dir, maven_cp)

	-- Create the embedded Lua test script
	local test_script = string.format([[
local test_file = vim.fn.argv()[1]
local classpath = vim.fn.argv()[2]

-- Install mocks for jdtls-dependent modules BEFORE loading neotest-java
require("tests.e2e.mocks").install_mocks(classpath)

-- Setup neotest
local neotest = require("neotest")
neotest.setup({
  adapters = {
    require("neotest-java")({
      ignore_wrapper = false,
    })
  },
})

-- Run tests asynchronously
vim.schedule(function()
  local nio = require("nio")
  nio.run(function()
    -- Call run - this will register the adapter and execute tests
    neotest.run.run(test_file)

    -- Wait for test execution to complete using status_counts
    local max_attempts = 40  -- 20 seconds (500ms * 40)
    local attempt = 0
    local counts = nil

    while attempt < max_attempts do
      nio.sleep(500)
      attempt = attempt + 1

      -- Get adapter IDs (should be populated after run())
      local adapter_ids = neotest.state.adapter_ids()
      if #adapter_ids == 0 then
        -- Adapter not registered yet, keep waiting
        goto continue
      end

      -- Get status counts from the registered adapter
      local adapter_id = adapter_ids[1]
      counts = neotest.state.status_counts(adapter_id)

      -- Check if tests have finished (no tests running)
      if counts and counts.running == 0 and counts.total > 0 then
        -- Tests are complete!
        break
      end

      ::continue::
    end

    if not counts or counts.total == 0 then
      local f = io.open("/tmp/neotest-e2e-error.txt", "w")
      if f then
        f:write("Timeout: No test results after " .. attempt .. " attempts\n")
        f:close()
      end
      vim.schedule(function()
        vim.cmd("cquit 1")
      end)
      return
    end

    -- Write status counts as JSON for snapshot testing
    local f = io.open("/tmp/neotest-e2e-results.json", "w")
    if f then
      f:write(vim.fn.json_encode(counts))
      f:close()
    end

    vim.schedule(function()
      vim.cmd("quitall")
    end)
  end)
end)

-- Overall timeout (30 seconds)
vim.defer_fn(function()
  local f = io.open("/tmp/neotest-e2e-error.txt", "w")
  if f then
    f:write("Global timeout (30s) reached\n")
    f:close()
  end
  vim.cmd("cquit! 1")
end, 30000)
]])

	local test_script_path = "/tmp/neotest-e2e.lua"
	write_file(test_script_path, test_script)

	-- Run the E2E test
	log_info("Running tests via Neotest...")
	os.remove("/tmp/neotest-e2e-results.json")
	os.remove("/tmp/neotest-e2e-error.txt")

	local nvim_cmd = string.format(
		'nvim --headless --noplugin -u tests/testrc.vim -c "luafile %s" %s %s 2>&1 | tee /tmp/neotest-e2e.log',
		test_script_path,
		vim.fn.shellescape(test_file),
		vim.fn.shellescape(full_cp)
	)

	local nvim_result, nvim_success = execute(nvim_cmd)

	if not nvim_success then
		log_error("Neovim exited with error")
		if file_exists("/tmp/neotest-e2e-error.txt") then
			print(read_file("/tmp/neotest-e2e-error.txt"))
		end
		if file_exists("/tmp/neotest-e2e.log") then
			print(read_file("/tmp/neotest-e2e.log"))
		end
		os.exit(1)
	end

	if file_exists("/tmp/neotest-e2e-error.txt") then
		log_error("Test execution failed")
		print(read_file("/tmp/neotest-e2e-error.txt"))
		if file_exists("/tmp/neotest-e2e.log") then
			print(read_file("/tmp/neotest-e2e.log"))
		end
		os.exit(1)
	end

	if not file_exists("/tmp/neotest-e2e-results.json") then
		log_error("No results generated")
		if file_exists("/tmp/neotest-e2e.log") then
			print(read_file("/tmp/neotest-e2e.log"))
		end
		os.exit(1)
	end

	log_success("Tests executed")

	-- Compare with snapshot
	local snapshot_file = proj_root .. "/tests/e2e/__snapshots__/maven-simple.json"

	if not file_exists(snapshot_file) then
		log_info("⚠ Snapshot file not found. Creating new snapshot at:")
		log_info("  " .. snapshot_file)
		mkdir_p(proj_root .. "/tests/e2e/__snapshots__")
		execute(string.format("cp /tmp/neotest-e2e-results.json %s", vim.fn.shellescape(snapshot_file)))
		log_success("Snapshot created")
		os.exit(0)
	end

	-- Compare results
	local match, actual, expected = compare_json_files("/tmp/neotest-e2e-results.json", snapshot_file)

	if match then
		log_success("E2E TEST PASSED - Results match snapshot")
	else
		log_error("Results don't match snapshot")
		log_info("Expected:")
		print(expected)
		log_info("Actual:")
		print(actual)
		log_info("Diff:")
		execute(
			string.format(
				"diff <(echo %s) <(echo %s) || true",
				vim.fn.shellescape(expected or ""),
				vim.fn.shellescape(actual or "")
			)
		)
		os.exit(1)
	end

	-- Cleanup
	os.remove("/tmp/neotest-e2e.lua")
	os.remove("/tmp/neotest-e2e-results.json")
	os.remove("/tmp/neotest-e2e-error.txt")
	os.remove("/tmp/neotest-e2e.log")
	os.remove("/tmp/maven-classpath.txt")

	print("")
	log_section("E2E Test Complete")
end

-- Run main function with error handling
local success, err = pcall(main)
if not success then
	log_error("Unexpected error: " .. tostring(err))
	os.exit(1)
end
