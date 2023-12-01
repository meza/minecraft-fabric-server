#!/bin/bash
URL="https://api.github.com/repos/meza/minecraft-mod-manager/releases/latest"


if [ -z "$GITHUB_TOKEN" ]; then
  JSON=$(curl -s --request GET --url "$URL")
else
  JSON=$(curl -s --request GET --url "$URL" \
  --header "X-GitHub-Api-Version: 2022-11-28" \
  --header "Authorization: Bearer $GITHUB_TOKEN")
fi

echo $JSON | \
jq -r '.assets[] | select(.label | contains("Linux")) | .browser_download_url' | \
xargs wget -O /tmp/mmm.zip && \
unzip -o /tmp/mmm.zip -d /minecraft/server
