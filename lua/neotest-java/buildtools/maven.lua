---comment
---@param self CommandBuilder
---@return table<string>
local function build_maven(self)
	local command = {}

	if self:contains_integration_tests() then
		table.insert(command, "verify")
	else
		table.insert(command, "test")
	end

	local references = {}
	for _, v in ipairs(self._test_references) do
		-- for some reason this sometimes is nil
		if v.qualified_name == nil then
		-- do nothing
		else
			local test_reference = self:_create_method_qualified_reference(v.qualified_name, v.method_name)
			table.insert(references, test_reference)
		end
	end
	table.insert(command, "-Dtest=" .. table.concat(references, ","))

	return command
end

---@class neotest-java.BuildTool
return {
	name = "maven",
	wrapper = "./mvnw",
	global_binary = "mvn",
	project_files = {
		"pom.xml",
	},
	reports_dir = "/target/surefire-reports",
	test_src = "src/test/java/",
	build_command = build_maven,
}
