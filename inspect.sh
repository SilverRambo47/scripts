#!/bin/sh
# ------------------------------------------------------
# GoLand offline inspection script.
# ------------------------------------------------------

# shellcheck disable=SC2155
export DEFAULT_PROJECT_PATH="$(pwd)"

IDE_BIN_HOME="${0%/*}"
exec "$IDE_BIN_HOME/goland.sh" inspect "$@"