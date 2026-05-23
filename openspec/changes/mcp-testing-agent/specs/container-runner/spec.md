## ADDED Requirements

### Requirement: Runner script exists

The system SHALL provide a `scripts/mcp-test-runner.sh` script that manages container lifecycle with `--start`, `--stop`, and `--list` commands.

#### Scenario: Start container

- **WHEN** invoked as `scripts/mcp-test-runner.sh --start --fixture maven-simple`
- **THEN** it SHALL start a Docker container, assign a unique host port, wait for Neovim readiness, and output a JSON object with `containerId`, `hostPort`, and `fixture`

#### Scenario: Stop container

- **WHEN** invoked as `scripts/mcp-test-runner.sh --stop <container-id>`
- **THEN** it SHALL stop and remove the specified container

#### Scenario: List running containers

- **WHEN** invoked as `scripts/mcp-test-runner.sh --list`
- **THEN** it SHALL list all running test containers with their container ID, host port, and fixture name

### Requirement: Prerequisites validation

The runner script SHALL validate that Docker is installed, the daemon is running, and the `neotest-java-tester` image exists before starting a container.

#### Scenario: Docker not available

- **WHEN** Docker is not installed or the daemon is not running
- **THEN** the script SHALL print an error message and exit with code 1

#### Scenario: Image not found

- **WHEN** the `neotest-java-tester` image does not exist locally
- **THEN** the script SHALL print a message instructing the user to run `make docker-test-image` and exit with code 1

### Requirement: Unique port per container

Each started container SHALL use a dynamically assigned unique host port so multiple containers can run in parallel.

#### Scenario: No port conflicts

- **WHEN** two containers are started in sequence
- **THEN** each SHALL use a different host port
