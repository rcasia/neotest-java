#!/bin/sh
# entrypoint.sh — sets JAVA_HOME dynamically before running commands
JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
export JAVA_HOME
exec "$@"
