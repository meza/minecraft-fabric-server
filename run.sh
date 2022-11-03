#!/bin/bash

if [ -z "$1" ]; then
  docker run --rm -it \
    --name "mct" \
    -e LOCAL_UID="$(id -u "$USER")" \
    -e LOCAL_GID="$(id -g "$USER")" \
    -e RCON_PASSWORD="test" \
    -e BACKUP_PATH="file:///minecraft/backups" \
    --env-file .env \
    --hostname "mct" \
    -v"$(pwd)/tmp/world:/minecraft/world" \
    -v"$(pwd)/tmp/config:/minecraft/config" \
    -v"$(pwd)/tmp/server:/minecraft/server" \
    mctest
else
  docker run --rm -it \
    --name "mct" \
    -e RCON_PASSWORD="test" \
    -e LOCAL_UID="$(id -u "$USER")" \
    -e LOCAL_GID="$(id -g "$USER")" \
    --hostname "mct" \
    -e BACKUP_PATH="file:///minecraft/backups" \
    --env-file .env \
    -v"$(pwd)/tmp/world:/minecraft/world" \
    -v"$(pwd)/tmp/config:/minecraft/config" \
    -v"$(pwd)/tmp/server:/minecraft/server" \
    mctest "$1"
fi
