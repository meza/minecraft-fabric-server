#!/usr/bin/env bash

# Minecraft Fabric Server Setup Script
# 
# This script configures and starts a Minecraft Fabric server with optimized JVM settings.
# 
# Key Environment Variables (see README.md for detailed documentation):
# - Memory: XMS, XMX, XMN
# - GC Performance: G1_HEAP_REGION_SIZE, PARALLEL_GC_THREADS, CONCURRENT_GC_THREADS  
# - Optimizations: USE_STRING_DEDUPLICATION, OPTIMIZE_STRING_CONCAT
# - Server: MINECRAFT_PORT, RCON_PORT, RCON_PASSWORD
# - Features: AUTO_UPDATE_MODS, AUTO_UPDATE_FABRIC, BACKUP_ON_START

export MCDIR=/minecraft
export SETUP_FILES=$MCDIR/setup-files
export BACKUPS=$MCDIR/backups
export WORLD=$MCDIR/world
export SERVER=$MCDIR/server
export JAVA_BIN=/opt/java/openjdk/bin/java
MC_VERSION=$(cat /minecraft/installed-version.txt)
export MC_VERSION

if [ -z "$DATE" ]; then
  DATE=$(date +%Y-%m-%d_%H-%M-%S)
  export DATE
fi

source /minecraft/scripts/functions.sh

# Validate configuration parameters to prevent common mistakes
validate_config() {
  echo "**** Validating configuration parameters ****"
  
  # Validate memory settings
  if [[ ! "$XMS" =~ ^[0-9]+[mMgG]$ ]]; then
    echo "WARNING: XMS should end with 'm' or 'g' (e.g., 2g, 512m)"
  fi
  
  if [[ ! "$XMX" =~ ^[0-9]+[mMgG]$ ]]; then
    echo "WARNING: XMX should end with 'm' or 'g' (e.g., 4g, 2048m)"
  fi
  
  if [ -n "$XMN" ] && [[ ! "$XMN" =~ ^[0-9]+[mMgG]$ ]]; then
    echo "WARNING: XMN should end with 'm' or 'g' (e.g., 1g, 512m)"
  fi
  
  # Validate GC thread counts (with safety checks)
  if [[ "$PARALLEL_GC_THREADS" =~ ^[0-9]+$ ]]; then
    if [ "${PARALLEL_GC_THREADS}" -gt 16 ]; then
      echo "WARNING: PARALLEL_GC_THREADS=${PARALLEL_GC_THREADS} seems high. Consider using CPU core count (typically 2-16)."
    fi
  else
    echo "WARNING: PARALLEL_GC_THREADS should be a positive integer - current value: $PARALLEL_GC_THREADS"
  fi
  
  if [[ "$CONCURRENT_GC_THREADS" =~ ^[0-9]+$ ]]; then
    if [ "${CONCURRENT_GC_THREADS}" -gt 8 ]; then
      echo "WARNING: CONCURRENT_GC_THREADS=${CONCURRENT_GC_THREADS} seems high. Consider using 1/4 of PARALLEL_GC_THREADS."
    fi
  else
    echo "WARNING: CONCURRENT_GC_THREADS should be a positive integer - current value: $CONCURRENT_GC_THREADS"
  fi
  
  # Validate heap region size
  if [ -n "$G1_HEAP_REGION_SIZE" ] && [[ ! "$G1_HEAP_REGION_SIZE" =~ ^[0-9]+[mMkK]$ ]]; then
    echo "WARNING: G1_HEAP_REGION_SIZE should end with 'm' or 'k' (e.g., 32m, 16m)"
  fi
  
  echo "**** Configuration validation complete ****"
}

# ------------------------------------------ UTILITY FUNCTIONS ---------------------------------------------------------

hydrate_config() {
  # Copies potential config files from within the container to the setup-files directory
  TYPE=$1
  EXCLUDES=$2

  for HC_FILE in "$SERVER"/*."$TYPE"; do
    if [ ! -f "$HC_FILE" ]; then
      continue
    fi

    HC_BASE=$(basename "$HC_FILE")
    HC_NAME="$SETUP_FILES/server/$HC_BASE"

    echo "Checking ${HC_BASE}"
    [[ ${EXCLUDES[*]} =~ ${HC_BASE} ]] && echo "excluding $HC_BASE" && continue

    if [ ! -f "$HC_NAME" ]; then
      cp "$HC_FILE" "$HC_NAME"
    fi
  done
}

# ------------------------------------------- RESTRICTED USER STUFF BELOW ----------------------------------------------

echo "**** Resetting the environment ****"

# Validate configuration early to catch issues
validate_config

rm -rf $SERVER/screenlog.0
rm -rf $SERVER/logs

mkdir -p $SETUP_FILES/server/
mkdir -p $SETUP_FILES/scripts/
mkdir -p "$SETUP_FILES/logs/$DATE"
mkdir -p $WORLD/datapacks

rm -rf "$SETUP_FILES/logs/latest" && ln -sfr "$SETUP_FILES/logs/$DATE" "$SETUP_FILES/logs/latest"
rm -rf $SERVER/logs && ln -sf "$SETUP_FILES/logs/$DATE" $SERVER/logs
rm -rf $SERVER/world && ln -s $WORLD $SERVER/world

# ---------------------------------- Copy config files to the volume ---------------------------------------------------

echo "**** Setting up the main minecraft files ****"

rsync -q -r --ignore-existing /minecraft/server-init/ /minecraft/server

excludes=(fabric-server-launcher.properties)

# shellcheck disable=SC2086
# shellcheck disable=SC2128
hydrate_config "json" $excludes

# shellcheck disable=SC2086
# shellcheck disable=SC2128
hydrate_config "properties" $excludes

# shellcheck disable=SC2086
# shellcheck disable=SC2128
hydrate_config "lock" $excludes

# shellcheck disable=SC2086
# shellcheck disable=SC2128
hydrate_config "png" $excludes

# shellcheck disable=SC2086
# shellcheck disable=SC2128
hydrate_config "conf" $excludes

# shellcheck disable=SC2086
# shellcheck disable=SC2128
hydrate_config "yml" $excludes

# shellcheck disable=SC2086
# shellcheck disable=SC2128
hydrate_config "db" $excludes

# shellcheck disable=SC2086
# shellcheck disable=SC2128
hydrate_config "txt" $excludes


mkdir -p "$SETUP_FILES/server/config"

#if [ -d $SERVER/config ]; then
#  mv $SERVER/config/* "$SETUP_FILES/server/config"
#fi

# ----------------------------------------------------------------------------------------------------------------------
# ---------------------------------- Replacing files from the volume ---------------------------------------------------

for HC_FILE in "$SETUP_FILES"/server/*; do
  HC_BASE=$(basename "$HC_FILE")
  # if target file exists, remove it
  if [ -f "$SERVER/$HC_BASE" ]; then
    rm -rf "${SERVER:?}/$HC_BASE"
  fi

  # if HC_BASE is server.properties, then we need to copy it to the server directory
  if [ "$HC_BASE" = "server.properties" ]; then
    echo "**** Copying server.properties ****"
    cp --remove-destination "$HC_FILE" "$SERVER/$HC_BASE"
    continue
  else
    if [ -f "$SERVER/$HC_BASE" ]; then
      rm -rf "${SERVER:?}/$HC_BASE"
    fi
    ln -sfr "$HC_FILE" "$SERVER/$HC_BASE"
  fi

done

if [ -d $SETUP_FILES/datapacks ]; then
  if [ -d $WORLD/datapacks ]; then
    echo "**** Removing existing datapacks ****"
    echo "**** Please put all datapacks in your setup-files/datapacks folder ****"
    rm -rf $WORLD/datapacks
  fi

  rsync -q -r --ignore-existing "$SETUP_FILES/datapacks" "$WORLD"
fi

# ----------------------------------------------------------------------------------------------------------------------
# -------------------------------------- Adjusting Configuration -------------------------------------------------------

if [ -f "$SETUP_FILES/scripts/configure.sh" ]; then
  echo "**** Running configure.sh ****"
  chmod +x "$SETUP_FILES/scripts/configure.sh"
  "$SETUP_FILES/scripts/configure.sh"
else
  cp /minecraft/scripts/templates/configure.sh "$SETUP_FILES/scripts/configure.sh" && \
  chmod +x "$SETUP_FILES/scripts/configure.sh"
fi

echo "**** Adjusting server.properties configuration ****"
setConfig "server-port" "${MINECRAFT_PORT}" "$SERVER/server.properties"
setConfig "query.port" "${QUERY_PORT}" "$SERVER/server.properties"
setConfig "rcon.port" "${RCON_PORT}" "$SERVER/server.properties"
setConfig "rcon.password" "${RCON_PASSWORD}" "$SERVER/server.properties"


# ----------------------------------------------------------------------------------------------------------------------
# ----------------------------------------- AUTO UPDATE ----------------------------------------------------------------

# if auto_update_fabric then call /minecraft/tools/install-fabric.sh

if [ "$AUTO_UPDATE_FABRIC" = true ]; then
  echo "**** Auto Updating Fabric ****"
  /minecraft/tools/install-fabric.sh "$MC_VERSION" "$SERVER" "minecraft_server.jar" "/minecraft/installer-metadata.xml" "/minecraft/loader-metadata.xml"
fi


if [ -f $SERVER/modlist.json ]; then

  mkdir -p $SERVER/mods

  echo "**** modlist.json found, replacing the loader and game version ****"

  # update the loader property in the modlist.json to fabric
  jq '.loader = "fabric"' $SERVER/modlist.json > $SERVER/modlist.json.tmp && mv $SERVER/modlist.json.tmp $SETUP_FILES/server/modlist.json

  # update the gameVersion property in the modlist.json to the current version
  jq '.gameVersion = "'"$MC_VERSION"'"' $SERVER/modlist.json > $SERVER/modlist.json.tmp && mv $SERVER/modlist.json.tmp $SETUP_FILES/server/modlist.json

  echo "**** Installing mods ****"
  (
    cd $SERVER || exit 1
    ./mmm install
  )
  if [ "$AUTO_UPDATE_MODS" = "true" ]; then
    echo "**** Auto Updating ****"
    (
      cd $SERVER || exit 1
      ./mmm update
    )
  fi
  if [ ! -f $SETUP_FILES/server/modlist-lock.json ]; then
    mv "$SERVER/modlist-lock.json" "$SETUP_FILES/server/modlist-lock.json"
    ln -sfr "$SETUP_FILES/server/modlist-lock.json" "$SERVER/modlist-lock.json"
  fi
else
  echo "**** no modlist.json exists, auto update can't happen ****"
fi

# ----------------------------------------------------------------------------------------------------------------------

stop_mc_now() {
  if ! numPlayers; then # if there are players, warn them
    tell_minecraft '/tellraw @a ["",{"text":"[SERVER] ","bold":true,"color":"yellow"},{"text":"Shutdown procedure begins in 1 minute.","color":"yellow"}]'
    echo "Stopping mc now with players online"
    sleep 60
  else
    echo "Stopping mc now without players online"
  fi
  tell_minecraft "save-all"
  if [ "$BACKUP_ON_STOP" = "true" ]; then
    tell_minecraft "save-off"
    tell_minecraft '/tellraw @a ["",{"text":"[SERVER] ","bold":true,"color":"yellow"},{"text":"Creating backup...","color":"yellow"}]'
    echo "Running backup"
    backup
    echo "Backup done"
    tell_minecraft '/tellraw @a ["",{"text":"[SERVER] ","bold":true,"color":"yellow"},{"text":"Backup done!","color":"yellow"}]'
    tell_minecraft "save-on"
  fi
  sleep 1
  tell_minecraft '/tellraw @a ["",{"text":"[SERVER] ","bold":true,"color":"yellow"},{"text":"Stopping...","color":"yellow"}]'
  tell_minecraft "stop"
}

stop_mc() {
  echo "Checking for players..."
  if numPlayers; then # if there are no players, stop now
    stop_mc_now
  else
    echo "**** Players are online, restarting in 5 minutes ****"
    tell_minecraft '/tellraw @a ["",{"text":"[SERVER] ","bold":true,"color":"yellow"},{"text":"Restart in 5 minutes.","color":"yellow"}]'
    sleep 120
    tell_minecraft '/tellraw @a ["",{"text":"[SERVER] ","bold":true,"color":"yellow"},{"text":"Restart in 3 minutes.","color":"yellow"}]'
    sleep 60
    tell_minecraft '/tellraw @a ["",{"text":"[SERVER] ","bold":true,"color":"yellow"},{"text":"Restart in 2 minutes.","color":"yellow"}]'
    sleep 60
  stop_mc_now
  fi
}

trap stop_mc SIGUSR1
trap stop_mc_now SIGTERM

echo "**** Starting Minecraft ****"
cd $SERVER || exit 1
screen -wipe 2>/dev/null

# if BACKUP_ON_STARTUP is true then run

if [ "$BACKUP_ON_STARTUP" = "true" ]; then
  echo "**** Running backup ****"
  backup
  echo "**** Backup done ****"
fi

# JVM Arguments Construction - Performance tuning configurable via environment variables
echo "**** Building JVM arguments for hardware optimization ****"

# Basic memory settings
JVM_ARGS="-Xms${XMS} -Xmx${XMX}"

# Young generation setting (if specified)
if [ -n "${XMN}" ]; then
  JVM_ARGS="${JVM_ARGS} -Xmn${XMN}"
fi

# Core JVM modules and GC selection
JVM_ARGS="${JVM_ARGS} --add-modules=jdk.incubator.vector"
JVM_ARGS="${JVM_ARGS} -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200"
JVM_ARGS="${JVM_ARGS} -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC"

# GC Threading configuration (parameterized for hardware optimization)
if [[ "${PARALLEL_GC_THREADS}" =~ ^[0-9]+$ ]] && [ "${PARALLEL_GC_THREADS}" -gt 0 ]; then
  JVM_ARGS="${JVM_ARGS} -XX:ParallelGCThreads=${PARALLEL_GC_THREADS}"
else
  echo "WARNING: PARALLEL_GC_THREADS must be a positive integer, using default"
fi

if [[ "${CONCURRENT_GC_THREADS}" =~ ^[0-9]+$ ]] && [ "${CONCURRENT_GC_THREADS}" -gt 0 ]; then
  JVM_ARGS="${JVM_ARGS} -XX:ConcGCThreads=${CONCURRENT_GC_THREADS}"
else
  echo "WARNING: CONCURRENT_GC_THREADS must be a positive integer, using default"
fi

# Core G1GC tuning (Aikar's flags)
JVM_ARGS="${JVM_ARGS} -XX:+AlwaysPreTouch -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4"
JVM_ARGS="${JVM_ARGS} -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90"
JVM_ARGS="${JVM_ARGS} -XX:MaxMetaspaceSize=1G -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32"
JVM_ARGS="${JVM_ARGS} -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1"

# G1 heap region optimization
if [ -n "${G1_HEAP_REGION_SIZE}" ]; then
  JVM_ARGS="${JVM_ARGS} -XX:G1HeapRegionSize=${G1_HEAP_REGION_SIZE}"
fi

# G1 generation sizing
JVM_ARGS="${JVM_ARGS} -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1ReservePercent=2"

# String optimizations (parameterized)
if [ "${USE_STRING_DEDUPLICATION}" = "true" ]; then
  JVM_ARGS="${JVM_ARGS} -XX:+UseStringDeduplication"
fi

if [ "${OPTIMIZE_STRING_CONCAT}" = "true" ]; then
  JVM_ARGS="${JVM_ARGS} -XX:+OptimizeStringConcat"
fi

# Aikar's flags identification
JVM_ARGS="${JVM_ARGS} -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true"

# Start Minecraft server with optimized JVM arguments
echo "Starting Minecraft with JVM args: ${JVM_ARGS}"
# shellcheck disable=SC2086 # Word splitting is intentional for JVM_ARGS
screen -L -Logfile "$SERVER/screenlog.0" -dmS minecraft "$JAVA_BIN" ${JVM_ARGS} \
  -cp "${SETUP_FILES}/server/lib/*" \
  -jar "${SERVER}/fabric-server-launch.jar" \
  nogui

MC_PID=$(screen -S minecraft -Q echo "\$PID")
echo "    Minecraft's pid is ${MC_PID}"
tail -f $SERVER/screenlog.0 &

echo
echo "**** Minecraft logs incoming ... ****"
while [ -e "/proc/$MC_PID" ]; do
  sleep .6
done

echo
echo "!!!! Minecraft has stopped, so can we !!!!"
exit 0
