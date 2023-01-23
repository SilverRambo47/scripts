#!/bin/sh
# ------------------------------------------------------
# GoLand formatting script.
# ------------------------------------------------------

IDE_BIN_HOME="${0%/*}"
exec "$IDE_BIN_HOME/goland.sh" format "$@"