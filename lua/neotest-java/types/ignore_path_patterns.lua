local IGNORE_PATH_PATTERNS = {
	"^build[/\\]", -- build directory at the root
	"[/\\]build[/\\]", -- build directory in subdirectories
	"^target[/\\]", -- target directory at the root (Maven)
	"[/\\]target[/\\]", -- target directory in subdirectories
	"^%.gradle[/\\]", -- .gradle directory at the root
	"[/\\]%.gradle[/\\]", -- .gradle directory in subdirectories
	"^%.mvn[/\\]", -- .mvn directory at the root
	"[/\\]%.mvn[/\\]", -- .mvn directory in subdirectories
	"%.class$", -- compiled Java class files
	"^%.settings[/\\]", -- .settings directory (Eclipse)
	"[/\\]%.settings[/\\]",
	"^%.project$", -- Eclipse project file
	"^%.classpath$", -- Eclipse classpath file
	"^gradle%.app%.settings$", -- Gradle app settings file
	"^gradlew$", -- Gradle wrapper script (Unix)
	"^gradlew%.bat$", -- Gradle wrapper script (Windows)
	"^gradle/wrapper[/\\]", -- Gradle wrapper directory
	"[/\\]%.idea[/\\]", -- IntelliJ IDEA directory
	"%.iml$", -- IntelliJ IDEA module files
	"[/\\]%.vscode[/\\]", -- Visual Studio Code directory
	"%.log$", -- Log files
	"^out[/\\]", -- Output directory
	"[/\\]out[/\\]",
	"[/\\]node_modules[/\\]", -- Node.js modules directory (if applicable)
	"^node_modules[/\\]",
	"%.jar$", -- JAR files
	"%.war$", -- WAR files
	"^%.DS_Store$", -- macOS file
	"^%.classpath$", -- Eclipse classpath file
}

return IGNORE_PATH_PATTERNS
