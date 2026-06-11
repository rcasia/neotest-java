# AGENTS.md

Instructions for AI agents working on the **neotest-java** codebase — a Neovim plugin (Lua) that integrates with `neotest` to discover and run Java tests.

## Quick start

```bash
make          # full install + test cycle (clones deps on first run)
make test     # unit suite via scripts/test
```

Test runner: `scripts/test` → `nvim --headless -u scripts/minimal_init.lua -c "lua MiniTest.run()"`. Single file: `bash scripts/test tests/unit/<file>_spec.lua`. Single test inside a file: not supported — narrow the file's `describe`/`it` blocks.

Lint / format:

```bash
stylua --check .                       # format check (CI runs this)
luacheck lua/neotest-java/...           # standard luacheck
lua-language-server --check .          # sumneko/lua-language-server diagnostics (CI)
```

## Codebase layout

```
lua/neotest-java/
  init.lua                  # entry point — NeotestJavaAdapter, wires all sub-modules
  build_tool/               # Maven + Gradle build-tool configs
  command/                  # junit launcher, command executor
  core/
    file_checker.lua        # matches test file names against config patterns
    positions_discoverer.lua
    result_builder.lua      # orchestrates the test-result flow
    spec_builder/           # builds the nvim LSP spec for neotest
    root_finder.lua
    junit_result_reader.lua # walks JUnit XML and produces JunitResult objects
  model/
    junit_result.lua        # the JunitResult class
    path.lua                # neotest-java.Path — wrap ALL file paths in this
  util/
    xml_reader.lua          # generic XML reader, injectable read_file/xml_parse
    read_xml_tag.lua        # (REMOVED — superseded by xml_reader.read_tag)
    checksums, dir_scan, etc.
```

## Architectural patterns

### Function-as-constructor (this codebase's DI style)

Every component that takes dependencies is a **function that returns an instance table** — NOT a class, NOT a metatable. The function is named with a capital-letter, takes a single `deps` table, and returns the public surface.

```lua
-- definition
local MyComponent = function(deps)
    deps = deps or {}
    -- fill defaults from real libs
    deps.foo = deps.foo or require("foo")
    deps.bar = deps.bar or function() end

    return {
        do_thing = function()
            return deps.foo() .. deps.bar()
        end,
    }
end

-- usage (at the call site, typically init.lua)
local c = MyComponent({ foo = my_stub, bar = my_counter })
c.do_thing()
```

Live examples: `XmlReader`, `JunitResultReader`, `ResultBuilder`, `FileChecker`, `SpecBuilder`. Always match this style for new components.

### Dependency defaults

When a component has defaults, the constructor **merges per-field**, not by replacing the whole table:

```lua
local defaults = default_deps()  -- lazy-loads heavy libs
deps.read_file = deps.read_file or defaults.read_file
deps.xml_parse = deps.xml_parse or defaults.xml_parse
```

This lets callers inject a subset (e.g., just `read_file`) and inherit the rest.

### Path handling

**Always wrap file paths in `neotest-java.model.path`** — never use raw strings. This keeps the codebase cross-platform (Windows uses `\\`).

```lua
local Path = require("neotest-java.model.path")
local p = Path("/foo/bar.xml")
print(tostring(p))           -- "/foo/bar.xml" on Unix, "\\foo\\bar.xml" on Windows
```

In tests, use `Path("/fake/path")` for stub paths and key stub lookup tables by `tostring(path)` — Lua tables use raw equality for keys, so two distinct `Path` instances with the same stringification would NOT match as keys. The `Path` `__eq` metamethod doesn't apply to table indexing.

### Type annotations

This project uses **sumneko/lua-language-server** annotations. Match the existing style:

```lua
--- @class neotest-java.MyClass
--- @field method fun(arg: string): boolean

--- @param deps neotest-java.MyClassDeps | nil
--- @return neotest-java.MyClass
local MyClass = function(deps) ... end
```

`neotest.Logger` is a class with many required fields. For test stubs that only implement `debug`/`warn`, **use a duck-typed union** in your dep type:

```lua
--- @field log? neotest.Logger | { debug: fun(...), warn: fun(...) }
```

Same trick for `XmlReader` stubs that only implement `parse`:

```lua
--- @field xml_reader? neotest-java.XmlReader | { parse: fun(filepath: neotest-java.Path | string): { tree: table, error: string } }
```

This keeps the CI `lua-language-server` check passing while allowing focused test doubles.

## Testing

### Two layers

- **Unit specs** (`tests/unit/test_<module>_spec.lua`) — drive the module with stub dependencies. No real I/O, no async context. Each test runs in single-digit ms.
- **Social specs** (`tests/unit/test_<module>_social_spec.lua`, optional) — wire a **real** `<module>` against stub lower-level collaborators to exercise integration without the full I/O stack. Use this when you want to verify realistic tree shapes, parser quirks, or cross-component contracts.

Both use `mini.test` (busted-compatible: `describe`/`it`/`before_each`/`after_each`). Assert with the project's `tests.assertions.eq` (deep equality with diff).

### Async tests

If a test needs the `nio` event loop, use the helper from `tests.async_helpers`:

```lua
local async = require("tests.async_helpers").async
it("does the thing", async(function()
    -- nio context available here
end))
```

`async(fn)` is just a wrapper that returns a function for `it`'s second arg. **Do not call it directly** (`async(fn)()` is wrong) — `it` invokes the returned function inside the test runner.

## OpenSpec workflow

This project uses OpenSpec for change management. The `openspec/changes/` directory holds active changes; `openspec/changes/archive/` holds archived ones; `openspec/specs/` holds the project's durable capability specs.

```
openspec/
  specs/                    # main capability specs (durable record)
    xml-reader/spec.md
    junit-result-reader/spec.md
    build-tool/spec.md
  changes/
    <active-change-name>/
      proposal.md           # WHY
      design.md             # HOW
      specs/<capability>/spec.md   # delta spec (ADDED/MODIFIED/REMOVED)
      tasks.md              # implementation checklist
    archive/YYYY-MM-DD-<name>/  # archived
```

Workflow:

1. `/opsx-propose <name>` — scaffold artifacts
2. `/opsx-apply <name>` — implement tasks
3. `openspec archive <name>` — promote delta spec to `openspec/specs/` and move the change to archive

**`openspec/` is gitignored locally** (via `.git/info/exclude`, the developer's per-machine file). The team's convention is to NOT commit openspec/ files. When you need to commit a new openspec/ artifact (e.g., to push a draft PR or document an archive), use `git add -f` to bypass.

**`.gitignore` has `openspec/changes/archive/`** so archived changes are never tracked. Force-add only the new main spec at `openspec/specs/<capability>/spec.md` (not the archive contents).

## Git conventions

### Branches

- `feat/<kebab-case-name>` for new functionality
- `refactor/<kebab-case-name>` for refactors
- One PR per change; cut a new branch from latest `main` for each

### Commits

Conventional Commits, scoped to the module(s) touched:

```
feat(xml): add testable XmlReader module
test(xml): add XmlReader spec covering all 9 scenarios from the spec
refactor(result_builder): use JunitResultReader as dep
fix(xml): mark XmlReaderDeps fields as optional in type annotation
chore(openspec): archive refactor-xml-reader and promote xml-reader spec
```

- **Atomic commits**: one logical change per commit. A "logical change" is roughly: new module + its tests, OR one migration step, OR one bug fix. The apply phase should produce a sequence of well-named commits that read top-to-bottom as a story.
- Commit early, commit often. A PR with 8 atomic commits is easier to review than one with 8 changes in a single commit.

### Pre-commit / pre-push hooks

`.pre-commit-config.yaml` runs these on every commit and push:

- commitizen (commit-msg format check)
- stylua (Lua format)
- luacheck (Lua lint)
- markdownlint (`--fix`, only on `*.md` files)
- `make test` (the full unit suite)

**For openspec/ `.md` files**: the OpenSpec schema requires H2 as the first heading and long lines, which conflicts with the repo's markdownlint rules (MD041, MD013). Bypass with `--no-verify` on the commit and the push.

**For markdown content in openspec/ files**: prefer `git commit --no-verify` over fighting the hook. The hook does `--fix` and may corrupt your content before failing.

## Common gotchas

1. **`require("neotest-java.util.xml_reader")` returns a TABLE** (the module exports `{ new = XmlReader, read_tag = ... }`). The constructor is `.new`. Forgetting the `.new` gives `attempt to call (a table value)`.

2. **`JunitResult:new(testcase, tempname)` expects `tempname: fun(): string`**, not a string. The function is called later by `JunitResult:result()`. Pass the function, not the result of calling it.

3. **The `nio` runtime is mocked in tests** (see `scripts/minimal_init.lua` — patches `nio.scheduler` to a no-op, patches `nio.tests.with_timeout` to use `fast_only=true`). If a test needs the event loop, use the `async` wrapper from `tests.async_helpers`.

4. **`vim.uv.os_tmpdir()`** is the cross-platform temp dir, but unit tests should use a fixed `TEMPNAME` from `os.getenv("TEMP") or os.getenv("TMP") or vim.uv.os_tmpdir()` so assertions are stable.

5. **`make install`** clones the test deps (mini.nvim, plenary, neotest, etc.) into `./.dependencies/`. If the C compiler for tree-sitter-java times out on Windows CI, that's a pre-existing CI flake — not a code bug.

6. **Run `lua-language-server --check .`** locally before pushing. It's part of CI and is the most common cause of a "ready to merge → checks fail" loop.

7. **The unit test suite runs in ~0.12s** (142+ cases). If a single test takes >5s, something is wrong — usually a missing `async` wrapper or a forgotten real I/O call in a stub.
