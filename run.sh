#!/bin/bash

if [ -z "$1" ]; then
  docker run --rm -it \
    --name "mct" \
    -e LOCAL_UID="$(id -u "$USER")" \
    -e LOCAL_GID="$(id -g "$USER")" \
    -e WHITELIST=true \
    --hostname "mct" \
    -v"$(pwd)/tmp/backups:/minecraft/backups" \
    -v"$(pwd)/tmp/world:/minecraft/world" \
    -v"$(pwd)/tmp/config:/minecraft/config" \
    -v"$(pwd)/tmp/server:/minecraft/server" \
    mctest
else
  docker run --rm -it \
    --name "mct" \
    -e LOCAL_UID="$(id -u "$USER")" \
    -e LOCAL_GID="$(id -g "$USER")" \
    -e WHITELIST=true \
    --hostname "mct" \
    -v"$(pwd)/tmp/backups:/minecraft/backups" \
    -v"$(pwd)/tmp/world:/minecraft/world" \
    -v"$(pwd)/tmp/config:/minecraft/config" \
    -v"$(pwd)/tmp/server:/minecraft/server" \
    mctest "$1"
fi
