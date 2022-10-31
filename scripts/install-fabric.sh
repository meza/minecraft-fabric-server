#!/usr/bin/env bash

MINECRAFT_VERSION=$1
MINECRAFT_DIR=$2
MINECRAFT_JAR=$3

echo "Installing Fabric for Minecraft $MINECRAFT_VERSION"

# Install Fabric
mkdir -p $MINECRAFT_DIR || exit 1
curl -o installer.jar https://maven.fabricmc.net/net/fabricmc/fabric-installer/0.11.1/fabric-installer-0.11.1.jar || exit 1
java -jar installer.jar server -mcversion $MINECRAFT_VERSION || exit 1

rm installer.jar
ls -lah
cp -rf libraries/ "$MINECRAFT_DIR" || exit 1
cp -f fabric-server-launch.jar "$MINECRAFT_DIR/fabric-server-launch.jar" || exit 1
echo serverJar=$MINECRAFT_JAR >> "$MINECRAFT_DIR/fabric-server-launcher.properties"
