# syntax=docker/dockerfile-upstream:master-labs
FROM openjdk:17-alpine as base
RUN apk add mc bash curl rsync rsnapshot libstdc++

COPY --link etc/ /etc

# RUN addgroup -S minecraft && adduser -S minecraft -G minecraft && \
#    mkdir -p /minecraft && \
#    chown -R minecraft:minecraft /minecraft

FROM base as mcrcon
WORKDIR /

RUN apk add git build-base && mkdir "mcrcon"

ADD --keep-git-dir=true https://github.com/Tiiffi/mcrcon.git /mcrcon

WORKDIR /mcrcon

RUN ls -lah .

RUN gcc -std=gnu11 -pedantic -Wall -Wextra -O2 -s -o mcrcon mcrcon.c


FROM base as minecraft
# Everything that is in preparation for the actual minecraft server
ARG MINECRAFT_VERSION
ARG RCON_PASSWORD="minecraft"
ARG RCON_PORT=25575
ARG MINECRAFT_PORT=25565
ARG QUERY_PORT=25565

RUN apk add jq

WORKDIR /

RUN mkdir -p /minecraft/config \
    && mkdir -p /minecraft/world \
    && mkdir -p /minecraft/backups \
    && mkdir -p /minecraft/server \
    && mkdir -p /minecraft/tools

RUN curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | jq -r '.latest.release' > /minecraft/latest-version.txt && \
    LATEST_VERSION=$(cat "/minecraft/latest-version.txt"); \
    curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | \
    jq --arg VERSION "${MINECRAFT_VERSION:-$LATEST_VERSION}" -r '.versions[] | select(.id == $VERSION) | .url' | \
    xargs curl -s | \
    jq -r '.downloads.server.url' | \
    xargs curl -s -o /minecraft/server/minecraft_server.jar

WORKDIR /minecraft/server

RUN java -Xmx1024M -Xms512M -jar /minecraft/server/minecraft_server.jar nogui && \
    rm -rf /minecraft/server/logs

RUN sed -i 's/enable-jmx-monitoring=false/enable-jmx-monitoring=true/g' /minecraft/server/server.properties && \
    sed -i "s/rcon.port=25575/rcon.port=$RCON_PORT/" /minecraft/server/server.properties && \
    sed -i "s/rcon.password=/rcon.password=$RCON_PASSWORD/g" /minecraft/server/server.properties && \
    sed -i "s/query.port=25565/query.port=$QUERY_PORT/g" /minecraft/server/server.properties && \
    sed -i "s/server.port=25565/server.port=$MINECRAFT_PORT/g" /minecraft/server/server.properties && \
    sed -i 's/enable-rcon=false/enable-rcon=true/g' /minecraft/server/server.properties && \
    echo "eula=true" > /minecraft/server/eula.txt

FROM base as fabric

WORKDIR /

ARG MINECRAFT_VERSION

COPY --from=minecraft /minecraft/latest-version.txt /minecraft/latest-version.txt

WORKDIR /tmp/fabric

COPY scripts/install-fabric.sh /tmp/scripts/install-fabric.sh

RUN LATEST_VERSION=$(cat "/minecraft/latest-version.txt"); /tmp/scripts/install-fabric.sh "${MINECRAFT_VERSION:-$LATEST_VERSION}" "/minecraft/server" "minecraft_server.jar"

FROM base as mmm

RUN apk add jq && \
    mkdir -p /minecraft/server && \
    curl -s https://api.github.com/repos/meza/minecraft-mod-manager/releases | \
    jq -r '.[0].assets[] | select(.label | contains("Linux")) | .browser_download_url' | \
    xargs curl -s -L -o /tmp/mmm.zip && \
    unzip /tmp/mmm.zip -d /minecraft/server

FROM base as backup

RUN apk add rsync rsnapshot libstdc++

COPY --link etc/ /etc

RUN (crontab -l ; echo "0 * * * * /usr/bin/rsnapshot hourly") | sort - | uniq - | crontab - && \
    (crontab -l ; echo "30 23 * * * /usr/bin/rsnapshot daily") | sort - | uniq - | crontab -

FROM backup as run

RUN apk add screen

COPY --from=minecraft /minecraft /minecraft
COPY --from=fabric /minecraft/server /minecraft/server
COPY --from=mmm /minecraft/server/mmm /minecraft/server/mmm
COPY --from=mcrcon /mcrcon/mcrcon /minecraft/tools/mcrcon

COPY scripts/start.sh /minecraft/server/start.sh
RUN chmod +x /minecraft/server/start.sh

ARG RCON_PASSWORD="minecraft"
ARG RCON_PORT=25575
ARG MINECRAFT_PORT=25565
ARG QUERY_PORT=25565

ENV PATH="$PATH:/minecraft/tools/mcrcon:/minecraft/server"
ENV NAME="minecraft"
ENV XMS=2g
ENV XMX=4g
ENV XMN=512m
ENV MAX_THREADS=8

EXPOSE ${MINECRAFT_PORT}
EXPOSE ${RCON_PORT}
EXPOSE ${QUERY_PORT}

VOLUME /minecraft/config
VOLUME /minecraft/world
VOLUME /minecraft/backups

STOPSIGNAL SIGUSR1

WORKDIR /minecraft/server
CMD ["start.sh"]
