## ADDED Requirements

### Requirement: Public deps accepts client_provider override

The adapter SHALL accept an optional `client_provider` field in the public `deps` table. When provided, the adapter SHALL use this function instead of the default `client_provider` for all LSP client interactions.

#### Scenario: User provides custom client_provider
- **WHEN** user calls the adapter with `deps = { client_provider = my_custom_provider }`
- **THEN** all internal components use `my_custom_provider` to obtain LSP clients

#### Scenario: User does not provide client_provider
- **WHEN** user calls the adapter with `deps = {}` or `deps = nil`
- **THEN** the adapter uses the default `client_provider` implementation

### Requirement: Public deps accepts classpath_provider override

The adapter SHALL accept an optional `classpath_provider` field in the public `deps` table. When provided, the adapter SHALL use this instance instead of constructing a default `ClasspathProvider`.

#### Scenario: User provides custom classpath_provider
- **WHEN** user calls the adapter with `deps = { classpath_provider = my_classpath_provider }`
- **THEN** `SpecBuilder` and `MethodIdResolver` use `my_classpath_provider.get_classpath`

#### Scenario: User does not provide classpath_provider
- **WHEN** user calls the adapter without `classpath_provider` in deps
- **THEN** the adapter constructs a default `ClasspathProvider` using the (possibly overridden) `client_provider`

### Requirement: Public deps accepts binaries override

The adapter SHALL accept an optional `binaries` field in the public `deps` table. When provided, the adapter SHALL use this instance instead of constructing a default `Binaries`.

#### Scenario: User provides custom binaries
- **WHEN** user calls the adapter with `deps = { binaries = my_binaries }`
- **THEN** `SpecBuilder` and `MethodIdResolver` use `my_binaries.java` and `my_binaries.javap`

#### Scenario: User does not provide binaries
- **WHEN** user calls the adapter without `binaries` in deps
- **THEN** the adapter constructs a default `Binaries` using the (possibly overridden) `client_provider`

### Requirement: Public deps accepts lsp_compiler override

The adapter SHALL accept an optional `lsp_compiler` field in the public `deps` table. When provided, the adapter SHALL use this instance's `compile` method instead of the default LSP-based compilation.

#### Scenario: User provides custom lsp_compiler
- **WHEN** user calls the adapter with `deps = { lsp_compiler = my_compiler }`
- **THEN** `SpecBuilder` calls `my_compiler.compile` during test spec building

#### Scenario: User does not provide lsp_compiler
- **WHEN** user calls the adapter without `lsp_compiler` in deps
- **THEN** the adapter uses the default LSP-based compiler

### Requirement: Public deps accepts build_tool_getter override

The adapter SHALL accept an optional `build_tool_getter` field in the public `deps` table. When provided, the adapter SHALL use this function instead of the default `build_tools.get` to determine the project's build tool.

#### Scenario: User provides custom build_tool_getter
- **WHEN** user calls the adapter with `deps = { build_tool_getter = my_getter }`
- **THEN** `SpecBuilder` calls `my_getter` to obtain the build tool configuration

#### Scenario: User does not provide build_tool_getter
- **WHEN** user calls the adapter without `build_tool_getter` in deps
- **THEN** the adapter uses the default `build_tools.get` function

### Requirement: Public deps accepts method_id_resolver override

The adapter SHALL accept an optional `method_id_resolver` field in the public `deps` table. When provided, the adapter SHALL use this instance instead of constructing a default `MethodIdResolver`.

#### Scenario: User provides custom method_id_resolver
- **WHEN** user calls the adapter with `deps = { method_id_resolver = my_resolver }`
- **THEN** `PositionDiscoverer` uses `my_resolver.resolve_complete_method_id`

#### Scenario: User does not provide method_id_resolver
- **WHEN** user calls the adapter without `method_id_resolver` in deps
- **THEN** the adapter constructs a default `MethodIdResolver` using the (possibly overridden) `classpath_provider`, `binaries`, and `command_executor`

### Requirement: Type annotations document component interfaces

Each injectable component SHALL have a clear `@class` type annotation in the public API. The `neotest-java.Dependencies` class annotation SHALL list all overridable fields with their expected types.

#### Scenario: User sees type hints for client_provider
- **WHEN** user reads the `neotest-java.Dependencies` type annotation
- **THEN** `client_provider` is documented as `fun(cwd: neotest-java.Path): vim.lsp.Client`

#### Scenario: User sees type hints for classpath_provider
- **WHEN** user reads the `neotest-java.Dependencies` type annotation
- **THEN** `classpath_provider` is documented as `neotest-java.ClasspathProvider`

### Requirement: Backward compatibility maintained

The adapter SHALL maintain 100% backward compatibility. Existing configurations that do not use the new `deps` fields SHALL continue to work unchanged.

#### Scenario: Existing config without new deps fields
- **WHEN** user calls the adapter with `deps = { root_finder = my_root_finder }` (existing field only)
- **THEN** the adapter behaves identically to before this change

#### Scenario: Existing config with no deps
- **WHEN** user calls the adapter with no `deps` argument
- **THEN** the adapter behaves identically to before this change
