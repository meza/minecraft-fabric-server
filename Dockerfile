# syntax=docker/dockerfile-upstream:master-labs@sha256:913bfe30d26221b867ddb690767011b1efb596e18a79195fdfd8060c7454286f
# @sha256:7949b5f4df3934290c60e5ebab01667a82c9d5c2e064c8d20120e54a56e9d6cb
FROM eclipse-temurin:25-alpine@sha256:0c4c6300cc86efdf6454702336a0d60352e227f3a862e8ae9861f393f8f1ede9 AS base

RUN echo http://dl-2.alpinelinux.org/alpine/edge/community/ >> /etc/apk/repositories && \
    echo http://dl-cdn.alpinelinux.org/alpine/edge/main >> /etc/apk/repositories && \
    apk update && \
    apk upgrade && \
    apk add --update mc bash perl curl wget rsync shadow coreutils gcompat libstdc++ jq screen sed busybox-suid

ENV PYTHONUNBUFFERED=1
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"


RUN apk add --update --no-cache gcompat python3 && \
    ln -sf python3 /usr/bin/python && \
    python3 -m venv $VIRTUAL_ENV && \
    python3 -m ensurepip && \
    apk add py3-setuptools && \
    pip3 install --no-cache --upgrade pip setuptools

RUN addgroup -g 1000 -S minecraft && adduser -D -u 1000 minecraft -G minecraft -s /bin/bash && \
    mkdir -p /minecraft && \
    chown -R minecraft:minecraft /minecraft

# ----------------------------------------------------------------------------------------------------------------------

FROM base AS minecraft
# Everything that is in preparation for the actual minecraft server
ARG MINECRAFT_VERSION
ARG RCON_PASSWORD="minecraft"
ARG RCON_PORT=25575
ARG MINECRAFT_PORT=25565
ARG QUERY_PORT=25565

WORKDIR /

RUN mkdir -p /minecraft/config \
    && mkdir -p /minecraft/world \
    && mkdir -p /minecraft/backups \
    && mkdir -p /minecraft/server \
    && mkdir -p /minecraft/tools \
    && echo ${MINECRAFT_VERSION} > /minecraft/version.txt

# Cache Busting - if necessary
ADD https://launchermeta.mojang.com/mc/game/version_manifest.json /minecraft/version_manifest.json

RUN cat /minecraft/version_manifest.json | jq -r '.latest.release' > /minecraft/latest-version.txt && \
    LATEST_VERSION=$(cat "/minecraft/latest-version.txt"); \
    curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | \
    jq --arg VERSION "${MINECRAFT_VERSION:-$LATEST_VERSION}" -r '.versions[] | select(.id == $VERSION) | .url' | \
    xargs curl -s | \
    jq -r '.downloads.server.url' | \
    xargs curl -s -o /minecraft/server/minecraft_server.jar && \
    echo "${MINECRAFT_VERSION:-$LATEST_VERSION}" > /minecraft/installed-version.txt

WORKDIR /minecraft/server

RUN java -Xmx1024M -Xms512M -jar /minecraft/server/minecraft_server.jar nogui && \
    rm -rf /minecraft/server/logs

RUN sed -i 's/enable-jmx-monitoring=false/enable-jmx-monitoring=true/g' /minecraft/server/server.properties && \
    sed -i "s/rcon.port=25575/rcon.port=$RCON_PORT/" /minecraft/server/server.properties && \
    sed -i "s/rcon.password=/rcon.password=$RCON_PASSWORD/g" /minecraft/server/server.properties && \
    sed -i "s/query.port=25565/query.port=$QUERY_PORT/g" /minecraft/server/server.properties && \
    sed -i "s/server-port=25565/server-port=$MINECRAFT_PORT/g" /minecraft/server/server.properties && \
    sed -i 's/enable-rcon=false/enable-rcon=true/g' /minecraft/server/server.properties && \
    echo "eula=true" > /minecraft/server/eula.txt

# ----------------------------------------------------------------------------------------------------------------------

FROM base AS fabric

WORKDIR /

COPY --from=minecraft /minecraft/installed-version.txt /minecraft/installed-version.txt

WORKDIR /tmp/fabric

# Cache Busting - if necessary
ADD https://maven.fabricmc.net/net/fabricmc/fabric-installer/maven-metadata.xml /minecraft/installer-metadata.xml
ADD https://maven.fabricmc.net/net/fabricmc/fabric-loader/maven-metadata.xml /minecraft/loader-metadata.xml

COPY --link scripts/install-fabric.sh /minecraft/tools/install-fabric.sh

RUN export MC_VERSION=$(cat "/minecraft/installed-version.txt") && \
    /minecraft/tools/install-fabric.sh "${MC_VERSION}" "/minecraft/server" "minecraft_server.jar" "/minecraft/installer-metadata.xml" "/minecraft/loader-metadata.xml"

# ----------------------------------------------------------------------------------------------------------------------

FROM base AS mcrcon
WORKDIR /

RUN apk add git build-base && mkdir "mcrcon"

ADD --keep-git-dir=true https://github.com/Tiiffi/mcrcon.git /mcrcon
COPY scripts/minecraft.sh /minecraft/tools/minecraft.sh

WORKDIR /mcrcon

RUN ls -lah .

RUN gcc -std=gnu11 -pedantic -Wall -Wextra -O2 -s -o mcrcon mcrcon.c

# ----------------------------------------------------------------------------------------------------------------------

FROM base AS backup

RUN apk add rsync duplicity duply gawk
RUN pip3 install boto3==1.15.3

COPY --link duply/ /home/minecraft/.duply

RUN touch /var/log/duply.log && \
    touch /var/log/duply.error && \
    chmod a+rw /var/log/duply* && \
    chown -R minecraft:minecraft /home/minecraft/.duply

# ----------------------------------------------------------------------------------------------------------------------

FROM backup AS prepare

COPY --from=minecraft /minecraft /minecraft
COPY --from=fabric /minecraft/server /minecraft/server
COPY --from=fabric /minecraft/fabric-launcher-version.txt /minecraft/fabric-launcher-version.txt
COPY --from=fabric /minecraft/tools/install-fabric.sh /minecraft/tools/install-fabric.sh
COPY --from=fabric /minecraft/loader-metadata.xml /minecraft/loader-metadata.xml
COPY --from=fabric /minecraft/installer-metadata.xml /minecraft/installer-metadata.xml
COPY --from=mcrcon /mcrcon/mcrcon /minecraft/tools/mcrcon
COPY --from=mcrcon /minecraft/tools/minecraft.sh /minecraft/tools/minecraft.sh


RUN mv -u /minecraft/server /minecraft/server-init && \
    mkdir -p /minecraft/server && \
    mkdir -p /minecraft/scripts && \
    chmod +x /minecraft/tools/mcrcon && \
    ln -sf /minecraft/tools/mcrcon /usr/bin/mcrcon && \
    chmod +x /minecraft/tools/minecraft.sh && \
    ln -sf /minecraft/tools/minecraft.sh /usr/bin/minecraft

COPY scripts/parts /minecraft/scripts
COPY scripts/setup-cron.sh /minecraft/scripts/setup-cron.sh
COPY scripts/start.sh /minecraft/start.sh

RUN chown -R minecraft:minecraft /minecraft && \
    chown -R minecraft:minecraft /home/minecraft && \
    chmod +x /minecraft/start.sh && \
    chmod +x /minecraft/scripts/**/*.sh

# ----------------------------------------------------------------------------------------------------------------------

FROM prepare AS run

ARG RCON_PASSWORD="minecraft"
ARG RCON_PORT=25575
ARG MINECRAFT_PORT=25565
ARG QUERY_PORT=25565

ENV PATH="$PATH:/minecraft/tools/mcrcon:/minecraft/server"
ENV NAME="minecraft"
ENV XMS=2g
ENV XMX=4g
ENV XMN=1g
ENV MAX_THREADS=8
# Performance tuning parameters - defaults optimized for i7-7700K (8 threads, 32GB RAM)
ENV G1_HEAP_REGION_SIZE=32M
ENV PARALLEL_GC_THREADS=8
ENV CONCURRENT_GC_THREADS=2
ENV USE_STRING_DEDUPLICATION=true
ENV OPTIMIZE_STRING_CONCAT=true
ENV AUTO_UPDATE_MODS=false
ENV AUTO_UPDATE_FABRIC=true
ENV RCON_PORT=25575
ENV MINECRAFT_PORT=25565
ENV QUERY_PORT=25565
ENV RCON_PASSWORD="minecraft"
ENV BACKUP_ON_START=true
ENV BACKUP_PATH="file:///minecraft/backups"
ENV BACKUP_ON_STOP=false

EXPOSE ${MINECRAFT_PORT}
EXPOSE ${RCON_PORT}
EXPOSE ${QUERY_PORT}

VOLUME /minecraft/setup-files
VOLUME /minecraft/world
VOLUME /minecraft/backups
#VOLUME /minecraft/server

STOPSIGNAL SIGUSR1

WORKDIR /minecraft/server

COPY --link scripts/healthcheck.sh /healthcheck.sh
COPY --link scripts/mmmInstall.sh /mmmInstall.sh

RUN chmod +x /healthcheck.sh
RUN chmod +x /mmmInstall.sh

HEALTHCHECK --interval=5s --timeout=2s --retries=3 --start-period=5m \
  CMD /healthcheck.sh

CMD ["/minecraft/start.sh"]
