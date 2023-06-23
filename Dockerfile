# syntax=docker/dockerfile-upstream:master-labs@sha256:ee2a1e5e7cb1effc2efedee71ff0511d2ca5d26ed1e2e644fb2a91a21143eeb9
# @sha256:7949b5f4df3934290c60e5ebab01667a82c9d5c2e064c8d20120e54a56e9d6cb
FROM eclipse-temurin:20-alpine as base

RUN echo http://dl-2.alpinelinux.org/alpine/edge/community/ >> /etc/apk/repositories && \
    apk update && \
    apk add mc bash perl curl wget rsync shadow coreutils gcompat libstdc++ jq

ENV PYTHONUNBUFFERED=1

RUN apk add --update --no-cache python3 && ln -sf python3 /usr/bin/python && \
    python3 -m ensurepip && \
    apk add py3-setuptools && \
    pip3 install --no-cache --upgrade pip setuptools

COPY --link etc/ /etc

RUN addgroup -g 1000 -S minecraft && adduser -D -u 1000 minecraft -G minecraft -s /bin/bash && \
    mkdir -p /minecraft && \
    chown -R minecraft:minecraft /minecraft

# ----------------------------------------------------------------------------------------------------------------------

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
    sed -i "s/server.port=25565/server.port=$MINECRAFT_PORT/g" /minecraft/server/server.properties && \
    sed -i 's/enable-rcon=false/enable-rcon=true/g' /minecraft/server/server.properties && \
    echo "eula=true" > /minecraft/server/eula.txt

# ----------------------------------------------------------------------------------------------------------------------

FROM base as fabric

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

FROM base as mmm

ADD "https://api.github.com/repos/meza/minecraft-mod-manager/releases/latest" /tmp/mmm.latest.json

RUN mkdir -p /minecraft/server && \
    cat /tmp/mmm.latest.json | \
    jq -r '.assets[] | select(.label | contains("Linux")) | .browser_download_url' | \
    xargs wget -O /tmp/mmm.zip && \
    unzip /tmp/mmm.zip -d /minecraft/server

FROM base as mcrcon
WORKDIR /

RUN apk add git build-base && mkdir "mcrcon"

ADD --keep-git-dir=true https://github.com/Tiiffi/mcrcon.git /mcrcon
COPY scripts/minecraft.sh /minecraft/tools/minecraft.sh

WORKDIR /mcrcon

RUN ls -lah .

RUN gcc -std=gnu11 -pedantic -Wall -Wextra -O2 -s -o mcrcon mcrcon.c

# ----------------------------------------------------------------------------------------------------------------------

FROM base as backup

RUN apk add rsync duplicity duply
RUN pip3 install boto3==1.15.3

COPY --link etc/duply/ /home/minecraft/.duply

RUN (crontab -l ; echo "0 * * * * /usr/bin/duply minecraft purgeAuto --force --allow-source-mismatch 2> /var/log/duply.err 1> /var/log/duply.log") | sort - | uniq - | crontab - && \
    (crontab -l ; echo "0 * * * * /usr/bin/duply minecraft backup now --allow-source-mismatch 2> /var/log/duply.error 1> /var/log/duply.log") | sort - | uniq - | crontab - && \
    (crontab -l ; echo "30 23 * * * /usr/bin/duply minecraft full now --allow-source-mismatch 2> /var/log/duply.error 1> /var/log/duply.log") | sort - | uniq - | crontab - && \
    touch /var/log/duply.log && \
    touch /var/log/duply.error && \
    chmod a+rw /var/log/duply*

# ----------------------------------------------------------------------------------------------------------------------

FROM backup as prepare

RUN apk add screen jq

COPY --from=minecraft /minecraft /minecraft
COPY --from=fabric /minecraft/server /minecraft/server
COPY --from=fabric /minecraft/fabric-launcher-version.txt /minecraft/fabric-launcher-version.txt
COPY --from=fabric /minecraft/tools/install-fabric.sh /minecraft/tools/install-fabric.sh
COPY --from=fabric /minecraft/loader-metadata.xml /minecraft/loader-metadata.xml
COPY --from=fabric /minecraft/installer-metadata.xml /minecraft/installer-metadata.xml
COPY --from=mmm /minecraft/server/mmm /minecraft/server/mmm
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
COPY scripts/start.sh /minecraft/start.sh

RUN chown -R minecraft:minecraft /minecraft && \
    chmod +x /minecraft/start.sh && \
    chmod +x /minecraft/scripts/**/*.sh

# ----------------------------------------------------------------------------------------------------------------------

FROM prepare as run

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
ENV AUTO_UPDATE_MODS=false
ENV AUTO_UPDATE_FABRIC=true
ENV RCON_PORT=25575
ENV MINECRAFT_PORT=25565
ENV QUERY_PORT=25565
ENV RCON_PASSWORD="minecraft"

ENV BACKUP_PATH="file:///minecraft/backups"

EXPOSE ${MINECRAFT_PORT}
EXPOSE ${RCON_PORT}
EXPOSE ${QUERY_PORT}

VOLUME /minecraft/setup-files
VOLUME /minecraft/world
VOLUME /minecraft/backups
VOLUME /minecraft/server

STOPSIGNAL SIGUSR1

WORKDIR /minecraft/server

HEALTHCHECK --start-period=5m --interval=1m --retries=30 --timeout=2s \
  CMD nc -zvw5 localhost $QUERY_PORT

CMD ["/minecraft/start.sh"]
