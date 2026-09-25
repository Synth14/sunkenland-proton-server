FROM ubuntu:22.04

LABEL description="Sunkenland Dedicated Server avec Proton GE"

ARG PROTON_VERSION=GE-Proton8-13
ARG PUID=1000
ARG PGID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    PROTON_VERSION=${PROTON_VERSION} \
    SUNKENLAND_APP_ID=2667530 \
    USER_HOME=/home/gameserver \
    WINEDEBUG=-all

# Configuration du jeu (surchargee par docker-compose)
ENV GAME_WORLD_GUID="" \
    GAME_PASSWORD="" \
    GAME_REGION="eu" \
    GAME_MAX_PLAYER=10 \
    GAME_SESSION_INVISIBLE=false \
    GAME_AUTO_UPDATE=true

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl python3 xvfb procps \
        lib32gcc-s1 libfreetype6 libvulkan1 mesa-vulkan-drivers && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix && \
    tr -d - < /proc/sys/kernel/random/uuid > /etc/machine-id && \
    groupadd -g ${PGID} gameserver && \
    useradd -m -u ${PUID} -g ${PGID} -d ${USER_HOME} -s /bin/bash gameserver

USER gameserver
WORKDIR ${USER_HOME}

# Dossiers crees ici pour que les volumes nommes heritent du bon proprietaire
RUN mkdir -p steamcmd sunkenland worlds \
        .steam/root/compatibilitytools.d \
        .steam/root/steamapps/compatdata

# Proton GE (couche separee: lourde et rarement modifiee)
RUN curl -fsSL "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_VERSION}/${PROTON_VERSION}.tar.gz" \
        | tar -xz -C .steam/root/compatibilitytools.d

# SteamCMD (le premier lancement sert a sa mise a jour)
RUN curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar -xz -C steamcmd && \
    (steamcmd/steamcmd.sh +quit || true)

COPY --chown=gameserver:gameserver --chmod=755 start.sh ${USER_HOME}/start.sh

ENTRYPOINT ["./start.sh"]
