#!/usr/bin/env bash

export MCDIR=/minecraft
export USER_ID=${LOCAL_UID:-1000}
export GROUP_ID=${LOCAL_GID:-1000}

USER=minecraft

usermod -u "$USER_ID" "$USER"
groupmod -g "$GROUP_ID" "$USER"

chown -R "$USER":"$USER" "$MCDIR"

# ------------------------------------------ THINGS TO DO AS ROOT ------------------------------------------------------

crond

echo "Installing MMM"
/mmmInstall.sh
echo "Installing MMM - done"

exec su "$USER" "/minecraft/scripts/setup.sh" -- "$@"
