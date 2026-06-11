# Contributing to neotest-java

Thanks for your interest in contributing! :confetti_ball:

## :inbox_tray: Pull Requests

For small changes, feel free to open a PR directly.
For larger changes, open an issue first to discuss the feature or bug.

To get your PR merged, you are expected to:

- Read this document
- Run the formatter before every commit
- Open a draft PR early to avoid duplicated work

### :electric_plug: Setup

#### Required dependencies

You will need:

- Java JDK 17 or 21
- The following tools available in your terminal:
  - pre-commit (<https://pre-commit.com/#install>)
  - `stylua`
  - `luacheck`
  - `make`
  - `git`

#### First build

Set up your environment by running:

```bash
make
```

This command will:

1. Clone neotest, plenary and nvim-treesitter
2. Install the Java parser for nvim-treesitter
3. Build the Java projects (some failing tests are expected)
4. Run the neotest-java test suite

#### Running tests

The project includes both unit tests and end-to-end (E2E) tests.

**Unit tests:**

```bash
# Run all unit tests
make test

# Run a single test file
./scripts/test [path-to-test-file]
```

You can also run unit tests from within Neovim using
[neotest-plenary](https://github.com/nvim-neotest/neotest-plenary).

> Note: you will need to specify the path to
> `.../neotest-java/tests/testrc.vim` in the neotest-plenary
> configuration. See nvim-neotest/neotest-plenary#13

**E2E tests:**

```bash
# Run E2E tests
make test-e2e

# Run all tests
make test && make test-e2e
```

E2E test requirements:

- Java JDK 17 or 21
- `JAVA_HOME` environment variable set
- Maven wrapper (included in the test fixture)

See [tests/e2e/README.md](tests/e2e/README.md) for detailed
E2E test documentation.

**Rebuilding after Java changes:**

If you change Java source files, rebuild before running tests:

```bash
make clean && make
```
