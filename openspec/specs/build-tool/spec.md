# build-tool

## Purpose

TBD — describe the build-tool capability at a high level.
## Requirements
### Requirement: build-tool get_build_dirname returns Path

The `get_build_dirname` function in build tool configurations SHALL return a `neotest-java.Path` representing the build directory. The `create_build_tool` factory uses this `Path` directly without re-wrapping.

#### Scenario: Gradle build tool returns Path build dirname
- **WHEN** `gradle.get_build_dirname` is called with any base directory
- **THEN** it returns `Path("bin")`

#### Scenario: Maven build tool returns Path build dirname
- **WHEN** `maven.get_build_dirname` is called with a base directory containing `pom.xml`
- **THEN** it returns `Path` wrapping the value of `project.build.directory` from pom.xml, or `Path("target")` if not defined

#### Scenario: Type annotation matches return type
- **WHEN** reading the `neotest-java.BuildTool` class annotation in `init.lua`
- **THEN** `get_build_dirname` is declared as returning `neotest-java.Path`

#### Scenario: create_build_tool does not double-wrap Path
- **WHEN** `create_build_tool` builds the `get_build_dirname` method
- **THEN** it returns the result from config directly without wrapping in `Path()`

