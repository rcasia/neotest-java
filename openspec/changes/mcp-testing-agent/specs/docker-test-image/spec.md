## ADDED Requirements

### Requirement: Dockerfile exists

The system SHALL provide a `Dockerfile.test` at the project root that builds a Docker image with Neovim, JDK, Maven, all test fixtures (pre-compiled), and neotest-java pre-installed.

#### Scenario: Image builds successfully

- **WHEN** `docker build -f Dockerfile.test -t neotest-java-tester .` is run
- **THEN** it SHALL produce an image named `neotest-java-tester:latest` with all dependencies installed

#### Scenario: Fixtures compiled at build time

- **WHEN** the Docker image is built
- **THEN** all test fixtures under `tests/fixtures/` SHALL be compiled (e.g., `mvnw clean test-compile` run during build) so containers start with ready-to-use class files

### Requirement: Minimal Neovim init config

The system SHALL provide a `docker/init.lua` file with a minimal Neovim configuration that loads neotest-java, neotest, nvim-nio, and plenary.nvim inside the container.

#### Scenario: Neovim starts with config

- **WHEN** Neovim starts inside the container
- **THEN** it SHALL load `docker/init.lua` and neotest-java SHALL be available

### Requirement: .dockerignore exists

The system SHALL provide a `.dockerignore` file excluding unnecessary build artifacts from the Docker build context.

#### Scenario: Build context is minimal

- **WHEN** `docker build` is run
- **THEN** directories `deps/`, `pack/`, `.git/`, `node_modules/` SHALL be excluded from the build context
