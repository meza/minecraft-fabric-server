#!/bin/bash

if [ -z "$1" ]; then
  docker run --rm -it \
    --name "mct" \
    -e LOCAL_UID="$(id -u "$USER")" \
    -e LOCAL_GID="$(id -g "$USER")" \
    -e RCON_PASSWORD="test" \
    -e BACKUP_PATH="file:///minecraft/backups" \
    --env-file .env \
    -v"$(pwd)/tmp/world:/minecraft/world" \
    -v"$(pwd)/tmp/config:/minecraft/config" \
    -v"$(pwd)/tmp/server:/minecraft/server" \
    -p 25565:25565 \
    -p 25575:25575 \
    mctest
else
  docker run --rm -it \
    --name "mct" \
    -e RCON_PASSWORD="test" \
    -e LOCAL_UID="$(id -u "$USER")" \
    -e LOCAL_GID="$(id -g "$USER")" \
    -e BACKUP_PATH="file:///minecraft/backups" \
    --env-file .env \
    -v"$(pwd)/tmp/world:/minecraft/world" \
    -v"$(pwd)/tmp/config:/minecraft/config" \
    -v"$(pwd)/tmp/server:/minecraft/server" \
    -p 25565:25565 \
    -p 25575:25575 \
    mctest "$1"
fi
