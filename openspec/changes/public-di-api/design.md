## Context

The neotest-java adapter currently uses constructor-based dependency injection internally, but the public `deps` parameter only exposes `root_finder` and `check_junit_jar_deps`. Core components like `client_provider`, `classpath_provider`, `binaries`, `lsp_compiler`, `build_tool_getter`, and `method_id_resolver` are hardcoded at initialization time.

The e2e test suite already demonstrates the pattern for swapping these components by monkey-patching `package.loaded`, proving the approach is viable. This change formalizes that pattern into a public API.

## Goals / Non-Goals

**Goals:**
- Allow users to override all major injectable components via the public `deps` argument
- Maintain 100% backward compatibility — existing configs work unchanged
- Provide clear `@class` type annotations so users know the interface to implement
- Document the API with examples in the README

**Non-Goals:**
- Changing the internal DI pattern (constructor-based injection remains)
- Supporting runtime component swapping after adapter initialization
- Adding new components or features beyond exposing existing ones
- Modifying the e2e test suite's monkey-patching approach (it continues to work)

## Decisions

**Decision 1: Expand the existing `deps` table rather than introducing a new parameter**

*Rationale:* The adapter already accepts `deps` as the second argument. Expanding it keeps the API surface minimal and follows the principle of least surprise. Users already know about `deps` from the existing `root_finder` override.

*Alternative considered:* A separate `overrides` parameter. Rejected because it adds API surface without clear benefit — `deps` already serves this purpose.

**Decision 2: Use optional fields with fallback to defaults**

Each new field in `deps` is optional. The adapter checks `deps.client_provider or default_client_provider` for each component. This ensures backward compatibility and allows partial overrides.

*Alternative considered:* Required fields with explicit `nil` for defaults. Rejected because it breaks existing configs and forces users to provide components they don't want to customize.

**Decision 3: Expose component constructors, not instances**

For components that require their own dependencies (e.g., `ClasspathProvider` needs `client_provider`), we expose the constructor function in `deps` so users can provide a fully-configured instance. This avoids coupling users to our internal dependency wiring.

*Alternative considered:* Expose individual leaf dependencies (e.g., `get_clients` function). Rejected because it leaks internal implementation details and makes the API fragile to refactoring.

**Decision 4: Type annotations use union types for flexibility**

Following the existing pattern in the codebase, type annotations use duck-typed unions (e.g., `neotest-java.ClientProvider | { __call: fun(cwd: neotest-java.Path): vim.lsp.Client }`) to allow both full implementations and minimal stubs.

## Risks / Trade-offs

**[Risk] Users provide incompatible component implementations** → Mitigation: Clear `@class` type annotations and README examples. Lua-language-server will catch type mismatches at edit time.

**[Risk] Internal refactoring breaks the public API** → Mitigation: The exposed components are already stable (used internally for years). If we refactor, we update the type annotations and document breaking changes.

**[Risk] Over-documentation leads to maintenance burden** → Mitigation: Focus README examples on the most common use cases (coc.nvim, custom classpath). Link to type annotations for full API reference.

**[Trade-off] Exposing constructors vs. instances** → We chose constructors for flexibility, but this means users must understand component dependencies. Acceptable because the target audience is advanced users who want full control.
