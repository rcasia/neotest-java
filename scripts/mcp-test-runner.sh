#!/bin/bash
# =============================================================================
# mcp-test-runner.sh — Container lifecycle manager for neotest-java testing
#
# Usage:
#   ./mcp-test-runner.sh --start --fixture <name>
#   ./mcp-test-runner.sh --stop <container-id>
#   ./mcp-test-runner.sh --list
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_NAME="neotest-java-tester:latest"
FIXTURES_JSON="$PROJECT_DIR/tests/fixtures/fixtures.json"
MCP_PORT_BASE=18901

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------
usage() {
    echo "Usage:"
    echo "  $0 --start --fixture <name>    Start a test container"
    echo "  $0 --stop <container-id>       Stop and remove a container"
    echo "  $0 --list                      List running test containers"
    exit 1
}

log() {
    echo "[mcp-test-runner] $*" >&2
}

die() {
    echo "[mcp-test-runner] ERROR: $*" >&2
    exit 1
}

# -----------------------------------------------------------------------------
# Prerequisites check
# -----------------------------------------------------------------------------
check_prereqs() {
    if ! docker info &>/dev/null; then
        die "Docker is not running. Please start Docker (e.g., 'colima start' or Docker Desktop)."
    fi

    if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
        die "Docker image '$IMAGE_NAME' not found. Run 'make docker-test-image' to build it."
    fi

    if ! command -v jq &>/dev/null; then
        die "jq is required but not found. Install it with 'brew install jq' or equivalent."
    fi
}

# -----------------------------------------------------------------------------
# Get the host port from a container (uses docker port to resolve dynamic port)
# -----------------------------------------------------------------------------
get_container_host_port() {
    local container_id="$1"
    local container_port="$2"
    docker port "$container_id" "$container_port" 2>/dev/null | head -1 | sed 's/.*://'
}

# -----------------------------------------------------------------------------
# --start: Start a new container
# -----------------------------------------------------------------------------
cmd_start() {
    local fixture=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --fixture) fixture="$2"; shift 2 ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    if [ -z "$fixture" ]; then
        die "--fixture is required"
    fi

    # Look up fixture path from fixtures.json
    if [ ! -f "$FIXTURES_JSON" ]; then
        die "Fixture registry not found at $FIXTURES_JSON"
    fi

    if ! command -v jq &>/dev/null; then
        die "jq is required but not found. Install it with 'brew install jq' or equivalent."
    fi

    local fixture_path
    fixture_path=$(jq -r --arg name "$fixture" '.[$name].path // empty' "$FIXTURES_JSON") || true
    if [ -z "$fixture_path" ]; then
        local available
        available=$(jq -r 'keys | join(", ")' "$FIXTURES_JSON")
        die "Fixture \"$fixture\" not found in $FIXTURES_JSON. Available: $available"
    fi

    check_prereqs

    local container_name="neotest-java-${fixture}-$$"
    local container_port=18901

    log "Starting container for fixture '$fixture' ..."

    local container_id
    container_id=$(docker run -d \
        --name "$container_name" \
        -P \
        --rm \
        "$IMAGE_NAME" \
        nvim --headless --listen "0.0.0.0:${container_port}" -c "lua vim.api.nvim_exec_autocmds('UIEnter', {})")

    local host_port
    host_port=$(get_container_host_port "$container_id" "$container_port")
    log "Container assigned to localhost:$host_port"

    # Wait for Neovim to be ready (TCP port accepting connections)
    local timeout=15
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        # Check if container is still running
        if ! docker ps -q --no-trunc | grep -q "$container_id"; then
            die "Container stopped unexpectedly. Logs: $(docker logs "$container_id" 2>&1)"
        fi
        # Test TCP connection to the Neovim listener
        if command -v nc &>/dev/null; then
            if nc -w 2 localhost "$host_port" </dev/null 2>/dev/null; then
                sleep 1
                break
            fi
        else
            # Fallback: just wait a fixed duration
            sleep 3
            break
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    if [ $elapsed -ge $timeout ]; then
        docker stop "$container_id" &>/dev/null || true
        die "Timed out waiting for Neovim to become ready on port $host_port"
    fi

    # Output connection details as JSON
    cat <<EOF
{
  "containerId": "$container_id",
  "hostPort": $host_port,
  "fixture": "$fixture",
  "containerName": "$container_name"
}
EOF
}

# -----------------------------------------------------------------------------
# --stop: Stop a container
# -----------------------------------------------------------------------------
cmd_stop() {
    if [ $# -lt 1 ]; then
        die "Usage: $0 --stop <container-id>"
    fi
    local container_id="$1"

    log "Stopping container $container_id ..."
    docker stop "$container_id" &>/dev/null || log "Container $container_id not found or already stopped"
    log "Container $container_id stopped and removed"
}

# -----------------------------------------------------------------------------
# --list: List running test containers
# -----------------------------------------------------------------------------
cmd_list() {
    docker ps \
        --filter "ancestor=$IMAGE_NAME" \
        --format '{{.ID}}\t{{.Names}}\t{{.Ports}}' \
        | while IFS=$'\t' read -r id name ports; do
            local fixture="${name#neotest-java-}"
            fixture="${fixture%-*}"
            cat <<EOF
{
  "containerId": "$id",
  "name": "$name",
  "ports": "$ports",
  "fixture": "$fixture"
}
EOF
        done

    if [ -z "$(docker ps -q --filter "ancestor=$IMAGE_NAME")" ]; then
        echo "[]"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if [ $# -eq 0 ]; then
    usage
fi

case "$1" in
    --start)
        shift
        cmd_start "$@"
        ;;
    --stop)
        shift
        cmd_stop "$@"
        ;;
    --list)
        cmd_list
        ;;
    *)
        usage
        ;;
esac
