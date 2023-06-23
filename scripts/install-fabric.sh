#!/usr/bin/env bash

MINECRAFT_VERSION=$1
MINECRAFT_DIR=$2
MINECRAFT_JAR=$3
INSTALLER_META_FILE=$4
LOADER_META_FILE=$5

LATEST_INSTALLER_VERSION=$(perl -0777 -ne 'print $1 if /<latest>(.*?)<\/latest>/s' "$INSTALLER_META_FILE")
LATEST_LOADER_VERSION=$(perl -0777 -ne 'print $1 if /<latest>(.*?)<\/latest>/s' "$LOADER_META_FILE")

LAUNCHER_URL="https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}/${LATEST_LOADER_VERSION}/${LATEST_INSTALLER_VERSION}/server/jar"

VERSION_FILE="$MINECRAFT_DIR/../fabric-launcher-version.txt"


if [ ! -f "$VERSION_FILE" ]; then
  ## Install Fabric
  echo "Installing Fabric ${LATEST_LOADER_VERSION} for Minecraft ${MINECRAFT_VERSION}"
  mkdir -p "$MINECRAFT_DIR" || exit 1
  wget -O installer.jar "https://maven.fabricmc.net/net/fabricmc/fabric-installer/${LATEST_INSTALLER_VERSION}/fabric-installer-${LATEST_INSTALLER_VERSION}.jar" || exit 1
  java -jar installer.jar server -mcversion "$MINECRAFT_VERSION" || exit 1

  rm installer.jar
  cp -rf libraries/ "$MINECRAFT_DIR" || exit 1
  cp -f fabric-server-launch.jar "$MINECRAFT_DIR/fabric-server-launch.jar" || exit 1
  echo serverJar="$MINECRAFT_JAR" >> "$MINECRAFT_DIR/fabric-server-launcher.properties"
  echo "${LATEST_INSTALLER_VERSION}" > "$VERSION_FILE"
else
  ## Update Fabric if needed
  echo "Checking for Fabric updates"
  CURRENT_INSTALLER_VERSION=$(cat "$VERSION_FILE")
  if [ "$CURRENT_INSTALLER_VERSION" != "$LATEST_INSTALLER_VERSION" ]; then
    echo "Updating Fabric from ${CURRENT_INSTALLER_VERSION} to ${LATEST_INSTALLER_VERSION}"

    mv "$MINECRAFT_DIR/fabric-server-launch.jar" "$MINECRAFT_DIR/fabric-server-launch.jar.old" || exit 1

    if wget -O "$MINECRAFT_DIR/fabric-server-launch.jar" "$LAUNCHER_URL"; then
      echo "Fabric was successfully updated to version $LATEST_INSTALLER_VERSION"
      echo "$LATEST_INSTALLER_VERSION" > "$VERSION_FILE"
      rm "$MINECRAFT_DIR/fabric-server-launch.jar.old"
    else
      echo "Failed to update Fabric to version $LATEST_INSTALLER_VERSION"
      echo "Reverting to previous version"
      mv "$MINECRAFT_DIR/fabric-server-launch.jar.old" "$MINECRAFT_DIR/fabric-server-launch.jar"
    fi

  fi
fi

