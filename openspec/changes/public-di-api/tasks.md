## 1. Type Annotations

- [ ] 1.1 Expand `neotest-java.Dependencies` class annotation in `init.lua` to include all overridable fields: `client_provider`, `classpath_provider`, `binaries`, `lsp_compiler`, `build_tool_getter`, `method_id_resolver`
- [ ] 1.2 Add clear type annotations for each field using existing `@class` definitions (e.g., `neotest-java.ClasspathProvider`, `neotest-java.LspBinaries`, `neotest-java.MethodIdResolver`)
- [ ] 1.3 Use function types for callable components (e.g., `client_provider: fun(cwd: neotest-java.Path): vim.lsp.Client`)

## 2. Wire Overrides in Adapter Initialization

- [ ] 2.1 Extract `client_provider` from `deps` with fallback to default: `deps.client_provider or default_client_provider`
- [ ] 2.2 Extract `classpath_provider` from `deps` with fallback: if not provided, construct default using the (possibly overridden) `client_provider`
- [ ] 2.3 Extract `binaries` from `deps` with fallback: if not provided, construct default using the (possibly overridden) `client_provider`
- [ ] 2.4 Extract `lsp_compiler` from `deps` with fallback to default LSP compiler
- [ ] 2.5 Extract `build_tool_getter` from `deps` with fallback to `build_tools.get`
- [ ] 2.6 Extract `method_id_resolver` from `deps` with fallback: if not provided, construct default using the (possibly overridden) `classpath_provider`, `binaries`, and `command_executor`
- [ ] 2.7 Pass all resolved components to downstream constructors (`SpecBuilder`, `PositionDiscoverer`, etc.)

## 3. Testing

- [ ] 3.1 Add unit test verifying custom `client_provider` is used when provided
- [ ] 3.2 Add unit test verifying custom `classpath_provider` is used when provided
- [ ] 3.3 Add unit test verifying custom `binaries` is used when provided
- [ ] 3.4 Add unit test verifying custom `lsp_compiler` is used when provided
- [ ] 3.5 Add unit test verifying custom `build_tool_getter` is used when provided
- [ ] 3.6 Add unit test verifying custom `method_id_resolver` is used when provided
- [ ] 3.7 Add unit test verifying defaults are used when no overrides provided (backward compatibility)
- [ ] 3.8 Run full unit test suite to ensure no regressions

## 4. Documentation

- [ ] 4.1 Add README section documenting the public DI API
- [ ] 4.2 Include example showing how to override `client_provider` for coc.nvim
- [ ] 4.3 Include example showing how to override `classpath_provider` for custom classpath resolution
- [ ] 4.4 Link to type annotations for full API reference

## 5. Verification

- [ ] 5.1 Run `stylua --check .` to ensure code formatting
- [ ] 5.2 Run `luacheck lua/neotest-java/...` to ensure no lint errors
- [ ] 5.3 Run `lua-language-server --check .` to ensure type annotations are correct
- [ ] 5.4 Run `make test` to ensure all tests pass
