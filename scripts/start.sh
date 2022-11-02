#!/usr/bin/env bash

export MCDIR=/minecraft
export CONFIGS=$MCDIR/config
export BACKUPS=$MCDIR/backups
export WORLD=$MCDIR/world
export SERVER=$MCDIR/server
export JAVA_BIN=/opt/openjdk-17/bin/java

export USER_ID=${LOCAL_UID:-1000}
export GROUP_ID=${LOCAL_GID:-1000}

if [ -z "$DATE" ]; then
  DATE=$(date +%Y-%m-%d_%H-%M-%S)
fi

# -------------------------------------------------- ROOT ACCESS -------------------------------------------------------
if [ -z "$1" ]; then

  usermod -u "$USER_ID" minecraft
  groupmod -g "$GROUP_ID" minecraft

  chown -R minecraft:minecraft "$MCDIR"

  echo "**** Starting Crond ****"
  crond
  user=minecraft
  exec su "$user" "$0" -- "stop"
fi
# ----------------------------------------------------------------------------------------------------------------------
# ------------------------------------------ UTILITY FUNCTIONS ---------------------------------------------------------

hydrate_config() {
  TYPE=$1
  EXCLUDES=$2

  for HC_FILE in "$SERVER"/*."$TYPE"; do
    if [ ! -f "$HC_FILE" ]; then
      continue
    fi

    HC_BASE=$(basename "$HC_FILE")
    HC_NAME="$CONFIGS/server/$HC_BASE"

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

mkdir -p $CONFIGS/server/
mkdir -p $CONFIGS/scripts/
mkdir -p "$CONFIGS/logs/$DATE"
mkdir -p $WORLD/datapacks

ln -sfr "$CONFIGS/logs/$DATE" "$CONFIGS/logs/latest"

ln -sf "$CONFIGS/logs/$DATE" $SERVER/logs

ln -sf $WORLD $SERVER/world

# ---------------------------------- Copy config files to the volume ---------------------------------------------------

echo "**** Setting up the main minecraft files ****"

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

# ----------------------------------------------------------------------------------------------------------------------
# ---------------------------------- Replacing files from the volume ---------------------------------------------------

for HC_FILE in "$CONFIGS"/server/*; do
  ln -sf "$HC_FILE" $SERVER/"$(basename "$HC_FILE")"
done

# ----------------------------------------------------------------------------------------------------------------------
# -------------------------------------- Adjusting Configuration -------------------------------------------------------

setConfig() {
  SC_FILE=${3:-"$SERVER/server.properties"}
  echo sed -i "s/$1=.*/$1=$2/g" "$SC_FILE"
  sed -i "s/$1=.*/$1=$2/g" "$SC_FILE"
}

export -f setConfig

setConfig "server-port" "${MINECRAFT_PORT}"
setConfig "query.port" "${QUERY_PORT}"
setConfig "rcon.port" "${RCON_PORT}"
setConfig "rcon.password" "${RCON_PASSWORD}"
setConfig "enable-rcon" "true"

if [ -f "$CONFIGS/scripts/configure.sh" ]; then
  echo "**** Running configure.sh ****"
  chmod +x "$CONFIGS/scripts/configure.sh"
  # SERVER="$SERVER" DATE="$DATE" MCDIR="$MCDIR" WORLD="$WORLD" CONFIGS="$CONFIGS" "$CONFIGS/scripts/configure.sh"
  "$CONFIGS/scripts/configure.sh"
fi

# ----------------------------------------------------------------------------------------------------------------------
# ----------------------------------------- AUTO UPDATE ----------------------------------------------------------------

if [ "$AUTO_UPDATE" = true ]; then
  echo "**** Auto Updating ****"
  if [ -f $CONFIGS/modlist.json ]; then
    cd $SERVER || exit 1
    ./mmm install && ./mmm update
  else
    echo "**** no modlist.json exists, auto update can't happen ****"
  fi
fi

# ----------------------------------------------------------------------------------------------------------------------

stop_mc() {
  screen -S minecraft -p 0 -X stuff '/tellraw @a ["",{"text":"[SERVER] ","bold":true,"color":"yellow"},{"text":"Restart in 5 minutes.","color":"yellow"}]^M'
  sleep 120
  screen -S minecraft -p 0 -X stuff '/tellraw @a ["",{"text":"[SERVER] ","bold":true,"color":"yellow"},{"text":"Restart in 3 minutes.","color":"yellow"}]^M'
  sleep 60
  screen -S minecraft -p 0 -X stuff '/tellraw @a ["",{"text":"[SERVER] ","bold":true,"color":"yellow"},{"text":"Restart in 2 minutes.","color":"yellow"}]^M'
  sleep 60
  screen -S minecraft -p 0 -X stuff '/tellraw @a ["",{"text":"[SERVER] ","bold":true,"color":"yellow"},{"text":"Restart in 1 minute.","color":"yellow"}]^M'
  echo "Stopping mc"
  sleep 60
  screen -S minecraft -p 0 -X stuff "save-all^M"
  screen -S minecraft -p 0 -X stuff "save-off^M"
  echo "Running backup"
  /usr/bin/duply minecraft backup now --allow-source-mismatch || echo "duply backup failed"
  echo "Backup done"
  screen -S minecraft -p 0 -X stuff "save-on^M"
  sleep 1
  screen -S minecraft -p 0 -X stuff "stop^M"
}

trap stop_mc SIGUSR1 SIGTERM

echo "**** Starting Minecraft ****"
cd $SERVER || exit 1
screen -wipe

/usr/bin/duply minecraft backup now --allow-source-mismatch || echo "duply backup failed"

screen -L -Logfile "$SERVER/screenlog.0" -dmS minecraft "$JAVA_BIN" -Xms${XMS} -Xmx${XMX} -XX:+AlwaysPreTouch \
  -XX:+ParallelRefProcEnabled -XX:+DisableExplicitGC -XX:+UseG1GC -Dsun.rmi.dgc.server.gcInterval=2147483646 \
  -XX:TargetSurvivorRatio=90 -XX:ParallelGCThreads=${MAX_THREADS} -XX:+UnlockDiagnosticVMOptions -XX:+UnlockExperimentalVMOptions \
  -XX:G1NewSizePercent=30 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=25 -XX:G1HeapRegionSize=8M -XX:G1HeapWastePercent=5 \
  -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 \
  -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true \
  -XX:UseAVX=2 -XX:+UseStringDeduplication -XX:+UseFastUnorderedTimeStamps -XX:+UseAES -XX:+UseAESIntrinsics -XX:UseSSE=4 -XX:AllocatePrefetchStyle=2 \
  -XX:+UseLoopPredicate -XX:+RangeCheckElimination -XX:+EliminateLocks -XX:+DoEscapeAnalysis -XX:+UseCodeCacheFlushing -XX:+UseFastJNIAccessors \
  -XX:+OptimizeStringConcat -XX:+UseCompressedOops -XX:+UseThreadPriorities -XX:+OmitStackTraceInFastThrow -XX:+TrustFinalNonStaticFields \
  -XX:ThreadPriorityPolicy=1 -XX:+UseInlineCaches -XX:+RewriteBytecodes -XX:+RewriteFrequentPairs -XX:+UseNUMA -XX:-DontCompileHugeMethods \
  -XX:+UseFPUForSpilling -XX:+UseNewLongLShift -XX:+UseVectorCmov -XX:+UseXMMForArrayCopy -XX:+UseXmmI2D -XX:+UseXmmI2F -XX:+UseXmmLoadAndClearUpper \
  -XX:+UseXmmRegToRegMoveAll -Dfile.encoding=UTF-8 -Djdk.nio.maxCachedBufferSize=262144 -Dgraal.TuneInlinerExploration=1 -Dgraal.CompilerConfiguration=enterprise \
  -Dgraal.UsePriorityInlining=true -Dgraal.Vectorization=true -Dgraal.OptDuplication=true -Dgraal.DetectInvertedLoopsAsCounted=true -Dgraal.LoopInversion=true \
  -Dgraal.VectorizeHashes=true -Dgraal.EnterprisePartialUnroll=true -Dgraal.VectorizeSIMD=true -Dgraal.StripMineNonCountedLoops=true -Dgraal.SpeculativeGuardMovement=true \
  -Dgraal.InfeasiblePathCorrelation=true --add-modules jdk.incubator.vector \
  -cp "fabric-server-launch.jar:lib/*:." net.fabricmc.loader.launch.server.FabricServerLauncher \
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
