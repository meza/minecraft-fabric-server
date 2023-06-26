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
