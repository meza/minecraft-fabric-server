#!/bin/bash

export MCRCON_PASS="$RCON_PASSWORD"
export MCRCON_HOST="localhost"
# shellcheck disable=SC2153 # RCON_PORT is a standard environment variable
export MCRCON_PORT="$RCON_PORT"

mcrcon "$*"
