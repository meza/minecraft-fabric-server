#!/bin/bash

tell_minecraft() {
  screen -S minecraft -p 0 -X stuff "$1^M"
}

export -f tell_minecraft

#-----------------------------------------------------------------------------------------------------------------------

backup() {
  echo "**** Backing up world ****"
  /usr/bin/duply minecraft backup now --allow-source-mismatch 2> /var/log/duply.error 1> /var/log/duply.log || \
  (echo "duply backup failed" && cat /var/log/duply.error)
}

export -f backup

#----------------------------------------------------------------------------------------------------------------------

setConfig() {
  SC_FILE=$3
  echo "Setting $1 in $SC_FILE"
  sed -i --follow-symlinks "s/$1=.*/$1=$2/g" "$SC_FILE"
}

export -f setConfig

#----------------------------------------------------------------------------------------------------------------------

numPlayers() {
  echo "**** Checking number of players ****"
  ONLINE=$(mcrcon -H 127.0.0.1 -P "$RCON_PORT" -p "$RCON_PASSWORD" list);
  if [[ "$ONLINE" =~ ^There[[:space:]]are[[:space:]]([[:digit:]]+).*$ ]]; then
    echo "There are ${BASH_REMATCH[1]} players online."
    return "${BASH_REMATCH[1]}";
  fi
  echo "Could not determine number of players online, assuming there are some."
  return 1;
}

export -f numPlayers
