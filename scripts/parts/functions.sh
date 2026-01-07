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
  ONLINE=$(mcrcon -H 127.0.0.1 -P $RCON_PORT -p $RCON_PASSWORD list);
  if [[ "$ONLINE" =~ ^There[[:space:]]are[[:space:]]([[:digit:]]+).*$ ]]; then
    echo "There are ${BASH_REMATCH[1]} players online."
    return ${BASH_REMATCH[1]};
  fi
  echo "Could not determine number of players online, assuming there are some."
  return 1;
}

export -f numPlayers

#----------------------------------------------------------------------------------------------------------------------

# Version comparison function to handle both old (1.x) and new (26.x) versioning schemes
# Returns 0 if version1 >= version2, 1 otherwise
version_gte() {
  local v1=$1
  local v2=$2
  
  # Extract major version from both
  local v1_major=$(echo "$v1" | grep -oP '^\d+' || echo "0")
  local v2_major=$(echo "$v2" | grep -oP '^\d+' || echo "0")
  
  # Compare major versions first
  if [ "$v1_major" -gt "$v2_major" ]; then
    return 0
  elif [ "$v1_major" -lt "$v2_major" ]; then
    return 1
  fi
  
  # Major versions are equal, compare full version strings
  # Remove snapshot/pre-release suffixes for comparison
  local v1_clean=$(echo "$v1" | sed -E 's/-(snapshot|pre|rc).*//')
  local v2_clean=$(echo "$v2" | sed -E 's/-(snapshot|pre|rc).*//')
  
  # Use sort -V for version comparison
  if [ "$(printf '%s\n' "$v2_clean" "$v1_clean" | sort -V | head -n1)" = "$v2_clean" ]; then
    return 0
  else
    return 1
  fi
}

export -f version_gte
