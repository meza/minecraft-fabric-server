#!/usr/bin/env bash

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

# ------------------------------------------ UTILITY FUNCTIONS ---------------------------------------------------------

hydrate_config() {
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

rm -rf $SERVER/screenlog.0
rm -rf $SERVER/logs

mkdir -p $SETUP_FILES/server/
mkdir -p $SETUP_FILES/scripts/
mkdir -p "$SETUP_FILES/logs/$DATE"
mkdir -p $WORLD/datapacks

rm -rf "$SETUP_FILES/logs/latest" && ln -sfr "$SETUP_FILES/logs/$DATE" "$SETUP_FILES/logs/latest"
rm -rf $SERVER/logs && ln -sf "$SETUP_FILES/logs/$DATE" $SERVER/logs
rm -rf $SERVER/world && ln -sf $WORLD $SERVER/world

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
mkdir -p "$SETUP_FILES/server/lib"

#if [ -d $SERVER/config ]; then
#  mv $SERVER/config/* "$SETUP_FILES/server/config"
#fi

# ----------------------------------------------------------------------------------------------------------------------
# ---------------------------------- Replacing files from the volume ---------------------------------------------------

for HC_FILE in "$SETUP_FILES"/server/*; do
  ln -sfr "$HC_FILE" "$SERVER/$(basename "$HC_FILE")"
done

ln -sfr "$SETUP_FILES/server/config" "$SERVER/config"

if [ -d $SETUP_FILES/server/datapacks ]; then
  ln -sfr "$SETUP_FILES/server/datapacks" "$WORLD/datapacks"
fi

# ----------------------------------------------------------------------------------------------------------------------
# -------------------------------------- Adjusting Configuration -------------------------------------------------------

setConfig "server-port" "${MINECRAFT_PORT}" "$SERVER/server.properties"
setConfig "query.port" "${QUERY_PORT}" "$SERVER/server.properties"
setConfig "rcon.port" "${RCON_PORT}" "$SERVER/server.properties"
setConfig "rcon.password" "${RCON_PASSWORD}" "$SERVER/server.properties"

if [ -f "$SETUP_FILES/scripts/configure.sh" ]; then
  echo "**** Running configure.sh ****"
  chmod +x "$SETUP_FILES/scripts/configure.sh"
  "$SETUP_FILES/scripts/configure.sh"
else
  cp /minecraft/scripts/templates/configure.sh "$SETUP_FILES/scripts/configure.sh" && \
  chmod +x "$SETUP_FILES/scripts/configure.sh"
fi


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
  if [ "$AUTO_UPDATE_MODS" = true ]; then
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
  tell_minecraft '/tellraw @a ["",{"text":"[SERVER] ","bold":true,"color":"yellow"},{"text":"Shutdown in 1 minute.","color":"yellow"}]'
  echo "Stopping mc"
  sleep 60
  tell_minecraft "save-all"
  tell_minecraft "save-off"
  echo "Running backup"
  backup
  echo "Backup done"
  tell_minecraft "save-on"
  sleep 1
  tell_minecraft "stop"
}

stop_mc() {
  tell_minecraft '/tellraw @a ["",{"text":"[SERVER] ","bold":true,"color":"yellow"},{"text":"Restart in 5 minutes.","color":"yellow"}]'
  sleep 120
  tell_minecraft '/tellraw @a ["",{"text":"[SERVER] ","bold":true,"color":"yellow"},{"text":"Restart in 3 minutes.","color":"yellow"}]'
  sleep 60
  tell_minecraft '/tellraw @a ["",{"text":"[SERVER] ","bold":true,"color":"yellow"},{"text":"Restart in 2 minutes.","color":"yellow"}]'
  sleep 60
  stop_mc_now
}

trap stop_mc SIGUSR1
trap stop_mc_now SIGTERM

echo "**** Starting Minecraft ****"
cd $SERVER || exit 1
screen -wipe 2>/dev/null

# if BACKUP_ON_STARTUP is true then run

if [ "$BACKUP_ON_STARTUP" = true ]; then
  echo "**** Running backup ****"
  backup
  echo "**** Backup done ****"
fi

screen -L -Logfile "$SERVER/screenlog.0" -dmS minecraft "$JAVA_BIN" -Xms${XMS} -Xmx${XMX} -XX:+AlwaysPreTouch \
  -XX:+ParallelRefProcEnabled -XX:+DisableExplicitGC -XX:+UseG1GC -Dsun.rmi.dgc.server.gcInterval=2147483646 \
  -XX:TargetSurvivorRatio=90 -XX:ParallelGCThreads=${MAX_THREADS} -XX:+UnlockDiagnosticVMOptions -XX:+UnlockExperimentalVMOptions \
  -XX:G1NewSizePercent=30 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=25 -XX:G1HeapRegionSize=8M -XX:G1HeapWastePercent=5 \
  -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 \
  -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true \
  -XX:UseAVX=2 -XX:+UseStringDeduplication -XX:+UseFastUnorderedTimeStamps -XX:+UseAES -XX:+UseAESIntrinsics -XX:UseSSE=4 -XX:AllocatePrefetchStyle=2 \
  -XX:+UseLoopPredicate -XX:+RangeCheckElimination -XX:+EliminateLocks -XX:+DoEscapeAnalysis -XX:+UseCodeCacheFlushing -XX:+UseFastJNIAccessors \
  -XX:+OptimizeStringConcat -XX:+UseCompressedOops -XX:+UseThreadPriorities -XX:+OmitStackTraceInFastThrow -XX:+TrustFinalNonStaticFields \
  -XX:+UseInlineCaches -XX:+RewriteBytecodes -XX:+RewriteFrequentPairs -XX:+UseNUMA -XX:-DontCompileHugeMethods \
  -XX:+UseFPUForSpilling -XX:+UseNewLongLShift -XX:+UseVectorCmov -XX:+UseXMMForArrayCopy -XX:+UseXmmI2D -XX:+UseXmmI2F -XX:+UseXmmLoadAndClearUpper \
  -XX:+UseXmmRegToRegMoveAll -Dfile.encoding=UTF-8 -Djdk.nio.maxCachedBufferSize=262144 -Dgraal.TuneInlinerExploration=1 -Dgraal.CompilerConfiguration=enterprise \
  -Dgraal.UsePriorityInlining=true -Dgraal.Vectorization=true -Dgraal.OptDuplication=true -Dgraal.DetectInvertedLoopsAsCounted=true -Dgraal.LoopInversion=true \
  -Dgraal.VectorizeHashes=true -Dgraal.EnterprisePartialUnroll=true -Dgraal.VectorizeSIMD=true -Dgraal.StripMineNonCountedLoops=true -Dgraal.SpeculativeGuardMovement=true \
  -Dgraal.InfeasiblePathCorrelation=true \
  -cp "${SETUP_FILES}/server/lib/*" \
  -jar "${SERVER}/fabric-server-launch.jar" \
  nogui

MC_PID=$(screen -S minecraft -Q echo '$PID')
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
