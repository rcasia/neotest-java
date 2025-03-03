local TEST_CLASS_PATTERNS = {
	"Test$",
	"Tests$",
	"Spec$",
	"IT$",
}

local JAVA_TEST_FILE_PATTERNS = {
	"Test%.java$",
	"Tests%.java$",
	"Spec%.java$",
	"IT%.java$",
}

return {
	TEST_CLASS_PATTERNS = TEST_CLASS_PATTERNS,
	JAVA_TEST_FILE_PATTERNS = JAVA_TEST_FILE_PATTERNS,
}
