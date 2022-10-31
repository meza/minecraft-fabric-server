#!/usr/bin/env bash

MCDIR=/minecraft
CONFIGS=$MCDIR/config
BACKUPS=$MCDIR/backups
WORLD=$MCDIR/world
SERVER=$MCDIR/server

echo "**** Resetting the environment ****"
rm -rf $SERVER/screenlog.0
rm -rf $CONFIGS/logs
rm -rf $SERVER/world

mkdir -p $WORLD/datapacks
mkdir -p $CONFIGS/server/

# ---------------------------------- Copy config files to the volume ---------------------------------------------------

echo "**** Setting up the main minecraft files ****"
rsync -zav --include="*.json" --exclude="/fabric-server-launcher.properties" --include="*.properties" --exclude="*" $SERVER/ $CONFIGS/server/

# ----------------------------------------------------------------------------------------------------------------------
# ---------------------------------- Replacing files from the volume ---------------------------------------------------

cp -rs $CONFIGS/server/* $SERVER/

# ----------------------------------------------------------------------------------------------------------------------
# --------------------------------------- Copying datapacks ------------------------------------------------------------

echo "**** Copying Datapacks ****"
cp -Rf /minecraft/datapacks/*.zip /world/datapacks/

# ----------------------------------------------------------------------------------------------------------------------

sed -i "s/NAME_REPLACE/${NAME}/g" /etc/rsnapshot.conf

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
  sleep 1
  screen -S minecraft -p 0 -X stuff "stop^M"
}

trap stop_mc SIGUSR1 SIGTERM

echo "**** Starting Crond ****"
crond

echo "**** Starting Minecraft ****"
cd $SERVER || exit 1
screen -wipe

screen -L -Logfile "$SERVER/screenlog.0" -dmS minecraft java -Xms${XMS} -Xmx${XMX} -XX:+AlwaysPreTouch \
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
echo .
echo "**** Waiting for Minecraft to stop ****"
while [ -e "/proc/$MC_PID" ]
do
  sleep .6
done

echo .
echo "!!!! Minecraft has stopped, so can we !!!!"
exit 0
