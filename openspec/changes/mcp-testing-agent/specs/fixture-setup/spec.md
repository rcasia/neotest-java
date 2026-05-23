## ADDED Requirements

### Requirement: Docker image with pre-compiled fixtures

The system SHALL provide a Dockerfile that builds an image containing Neovim, JDK, Maven, all test fixtures (pre-compiled), and neotest-java.

#### Scenario: Docker image builds

- **WHEN** `make docker-test-image` is run
- **THEN** it SHALL build a `neotest-java-tester` Docker image with all dependencies

#### Scenario: Fixtures compiled at build time

- **WHEN** the Docker image is built
- **THEN** all test fixtures SHALL be compiled so containers start with ready-to-use class files

### Requirement: Container runner script

The system SHALL provide a `scripts/mcp-test-runner.sh` script that manages container lifecycle: start a container for a given fixture/scenario, assign a unique port, return connection details, and stop the container.

#### Scenario: Start container

- **WHEN** invoked as `scripts/mcp-test-runner.sh --fixture maven-simple --port 9876`
- **THEN** it SHALL start a Docker container with Neovim, mount the fixture, and print the connection details as JSON

#### Scenario: Stop container

- **WHEN** invoked as `scripts/mcp-test-runner.sh --stop <container-id>`
- **THEN** it SHALL stop and remove the specified container

#### Scenario: Prerequisites check

- **WHEN** the script starts
- **THEN** it SHALL verify that Docker is installed and the `neotest-java-tester` image exists before attempting to start a container

### Requirement: Fixture registry

The system SHALL maintain a `tests/fixtures/fixtures.json` registry mapping fixture names to paths and descriptions so the agent can discover available fixtures.

#### Scenario: Agent lists fixtures

- **WHEN** the agent reads `tests/fixtures/fixtures.json`
- **THEN** it SHALL find entries for all available fixtures with their paths and descriptions
