#!/bin/bash

export MCRCON_PASS=$RCON_PASSWORD
export MCRCON_HOST="localhost"
export MCRCON_PORT=$RCON_PORT

mcrcon "$*"
