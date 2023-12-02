local function build_gradle(self)
	local command = {}

	table.insert(command, "test")

	for _, v in ipairs(self._test_references) do
		local test_reference = self:_create_test_reference(v.relative_path, v.method_name)
		table.insert(command, "--tests " .. test_reference)
	end

	return command
end

---@class neotest-java.BuildTool
return {
	name = "gradle",
	wrapper = "./gradlew",
	global_binary = "gradle",
	project_files = {
		"build.gradle",
		"build.gradle.kts",
	},
	reports_dir = "/build/test-results/test",
	test_src = "src/test/java/",
	build_command = build_gradle,
}
