FROM ubuntu:22.04

LABEL description="Sunkenland Dedicated Server avec Proton GE"

# Variables environnement pour configuration du serveur
ENV DEBIAN_FRONTEND=noninteractive \
    PROTON_VERSION="GE-Proton8-13" \
    SUNKENLAND_APP_ID=2667530 \
    USER_HOME="/home/gameserver" \
    SERVER_PORT=27015

# Variables configurables pour le jeu
ENV GAME_WORLD_GUID="" \
    GAME_PASSWORD="" \
    GAME_REGION="eu" \
    GAME_MAX_PLAYER=20 \
    GAME_SESSION_INVISIBLE=false \
    GAME_AUTO_UPDATE=true \
    GAME_SERVER_NAME="" 

# Installation des dépendances système
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    wget curl tar ca-certificates \
    xvfb python3 cabextract \
    lib32gcc-s1 libfreetype6 \
    libvulkan1 mesa-vulkan-drivers && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Création du dossier X11 et machine-id - FIX
RUN mkdir -p /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix && \
    echo "localmachine" > /etc/machine-id

# Création de l'utilisateur non-root
RUN useradd -m -d ${USER_HOME} -s /bin/bash gameserver

# Installation de SteamCMD
RUN mkdir -p ${USER_HOME}/steamcmd && \
    cd ${USER_HOME}/steamcmd && \
    wget -qO- https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar zxf - && \
    chown -R gameserver:gameserver ${USER_HOME}/steamcmd

# Installation de Proton GE
RUN mkdir -p ${USER_HOME}/.steam/root/compatibilitytools.d && \
    cd /tmp && \
    wget -q https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_VERSION}/${PROTON_VERSION}.tar.gz && \
    tar -xzf ${PROTON_VERSION}.tar.gz -C ${USER_HOME}/.steam/root/compatibilitytools.d && \
    rm ${PROTON_VERSION}.tar.gz && \
    mkdir -p ${USER_HOME}/.steam/steam && \
    ln -s ${USER_HOME}/.steam/root ${USER_HOME}/.steam/steam/root && \
    chown -R gameserver:gameserver ${USER_HOME}/.steam

# Création des dossiers pour le jeu
RUN mkdir -p ${USER_HOME}/sunkenland ${USER_HOME}/worlds && \
    chown -R gameserver:gameserver ${USER_HOME}/sunkenland ${USER_HOME}/worlds

# Passage à l'utilisateur non-root
USER gameserver
WORKDIR ${USER_HOME}

# Installation du serveur Sunkenland (en specifiant la plateforme Windows)
RUN ${USER_HOME}/steamcmd/steamcmd.sh +quit; \
    ${USER_HOME}/steamcmd/steamcmd.sh +@sSteamCmdForcePlatformType windows +force_install_dir ${USER_HOME}/sunkenland +login anonymous +app_update ${SUNKENLAND_APP_ID} validate +quit

# Script de lancement
COPY --chown=gameserver:gameserver --chmod=755 start.sh ${USER_HOME}/start.sh

# Exposition du port du serveur
EXPOSE ${SERVER_PORT}/udp

# Volume pour les mondes personnalisés
VOLUME ["${USER_HOME}/worlds"]

# Point d'entrée
ENTRYPOINT ["./start.sh"]