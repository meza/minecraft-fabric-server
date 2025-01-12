#!/bin/bash
URL="https://api.github.com/repos/meza/minecraft-mod-manager/releases/latest"

if [ -n "$MMM_URL" ]; then
  DOWNLOAD_URL="$MMM_URL"
else
  if [ -z "$GITHUB_TOKEN" ]; then
    JSON=$(curl -s --request GET --url "$URL")
  else
    JSON=$(curl -s --request GET --url "$URL" \
    --header "X-GitHub-Api-Version: 2022-11-28" \
    --header "Authorization: Bearer $GITHUB_TOKEN")
  fi

  DOWNLOAD_URL=$(echo $JSON | jq -r '.assets[] | select(.label | contains("Linux")) | .browser_download_url')
fi

wget -O /tmp/mmm.zip "$DOWNLOAD_URL" && \
unzip -o /tmp/mmm.zip -d /minecraft/server
