#!/bin/bash
curl -s "https://api.github.com/repos/meza/minecraft-mod-manager/releases/latest" | \
jq -r '.assets[] | select(.label | contains("Linux")) | .browser_download_url' | \
xargs wget -O /tmp/mmm.zip && \
unzip -o /tmp/mmm.zip -d /minecraft/server
