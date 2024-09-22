local take_just_the_dependency = require("neotest-java.util.just_take_the_dependency")

describe("take_just_the_dependency", function()
	local test_cases = {
		{
			input = "------javax.servlet:javax.servlet-api:jar:3.1.0:provided------",
			expected = "javax.servlet:javax.servlet-api:3.1.0",
		},
		{
			input = "[INFO]-----com.google.errorprone:error_prone_annotations:jar:2.28.0:compile",
			expected = "com.google.errorprone:error_prone_annotations:2.28.0",
		},
		{
			input = "[INFO]-org.hamcrest:hamcrest:jar:2.2:test",
			expected = "org.hamcrest:hamcrest:2.2",
		},
		{
			input = "org.hamcrest:hamcrest:jar:dto:2.2:test",
			expected = "org.hamcrest:hamcrest:2.2",
		},
		{
			input = "[INFO] +- org.hamcrest:hamcrest:jar:2.2:test",
			expected = "org.hamcrest:hamcrest:2.2",
		},
		{
			input = "2021-07-28T12:34:56Z",
			expected = nil,
		},
		{
			input = "GMT+1",
			expected = nil,
		},
		{
			input = "UTC-5:00",
			expected = nil,
		},
		{
			input = "[INFO] |    +- junit:junit:jar:4.12:compile",
			expected = "junit:junit:4.12",
		},
		{
			input = " junit:junit:4.12 (*)",
			expected = "junit:junit:4.12",
		},
		{
			input = "| +--- org.springframework.boot:spring-boot-starter:3.1.0",
			expected = "org.springframework.boot:spring-boot-starter:3.1.0",
		},
		{
			input = "+--- org.junit.platform:junit-platform-launcher:1.9.2 -> 1.9.3",
			expected = "org.junit.platform:junit-platform-launcher:1.9.3",
		},
		{
			input = "     |    \\--- org.junit.platform:junit-platform-launcher:1.9.2.RELEASE (*)",
			expected = "org.junit.platform:junit-platform-launcher:1.9.2.RELEASE",
		},
	}

	for _, case in ipairs(test_cases) do
		it(case.input, function()
			local result = take_just_the_dependency(case.input)
			assert.are.same(case.expected, result)
		end)
	end
end)
