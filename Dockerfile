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

# Installation du serveur Sunkenland (en spécifiant la plateforme Windows)
RUN ${USER_HOME}/steamcmd/steamcmd.sh +force_install_dir ${USER_HOME}/sunkenland +login anonymous +@sSteamCmdForcePlatformType windows +app_update ${SUNKENLAND_APP_ID} validate +quit

# Création du script de lancement
RUN echo '#!/bin/bash\n\
# Configuration de l\'environnement Proton\n\
export STEAM_COMPAT_CLIENT_INSTALL_PATH=${USER_HOME}/.steam/root\n\
export STEAM_COMPAT_DATA_PATH=${USER_HOME}/.steam/root/steamapps/compatdata/${SUNKENLAND_APP_ID}\n\
mkdir -p $STEAM_COMPAT_DATA_PATH\n\
\n\
# Mise à jour du jeu si demandé\n\
if [ "$GAME_AUTO_UPDATE" = "true" ]; then\n\
  echo "⏳ Vérification des mises à jour du serveur..."\n\
  ${USER_HOME}/steamcmd/steamcmd.sh +force_install_dir ${USER_HOME}/sunkenland +login anonymous +@sSteamCmdForcePlatformType windows +app_update ${SUNKENLAND_APP_ID} validate +quit\n\
fi\n\
\n\
# Vérification du WorldGUID\n\
if [ -z "$GAME_WORLD_GUID" ]; then\n\
  echo "❌ ERREUR: GAME_WORLD_GUID non défini! Le serveur ne peut pas démarrer sans ce paramètre."\n\
  echo "   Exemple: docker run -e GAME_WORLD_GUID=votre-guid-ici ..."\n\
  exit 1\n\
fi\n\
\n\
# Lien entre dossier des mondes et emplacement attendu par le jeu\n\
WORLD_PATH="${USER_HOME}/.steam/root/steamapps/compatdata/${SUNKENLAND_APP_ID}/pfx/drive_c/users/steamuser/AppData/LocalLow/Ambiens/Sunkenland/Worlds"\n\
mkdir -p "$(dirname "$WORLD_PATH")"\n\
rm -rf "$WORLD_PATH" 2>/dev/null\n\
ln -sf ${USER_HOME}/worlds "$WORLD_PATH"\n\
\n\
# Plus besoin de créer le .placeholder car les permissions sont corrigées\n\
# Construction des arguments de lancement\n\
ARGS="-batchmode -nographics -worldGuid $GAME_WORLD_GUID"\n\
\n\
if [ -n "$GAME_PASSWORD" ]; then\n\
  ARGS="$ARGS -serverPassword $GAME_PASSWORD"\n\
fi\n\
\n\
if [ -n "$GAME_REGION" ]; then\n\
  ARGS="$ARGS -serverRegion $GAME_REGION"\n\
fi\n\
\n\
if [ -n "$GAME_MAX_PLAYER" ]; then\n\
  ARGS="$ARGS -serverMaxPlayer $GAME_MAX_PLAYER"\n\
fi\n\
\n\
if [ "$GAME_SESSION_INVISIBLE" = "true" ]; then\n\
  ARGS="$ARGS -serverSessionInvisible"\n\
fi\n\
\n\
# Démarrage du serveur virtuel X avec configuration améliorée\n\
export DISPLAY=:0\n\
Xvfb :0 -screen 0 1024x768x16 -ac & \n\
XVFB_PID=$!\n\
\n\
echo "🚀 Démarrage du serveur Sunkenland avec les arguments:"\n\
echo "   $ARGS"\n\
\n\
# Fonction pour arrêter proprement le serveur\n\
function cleanup() {\n\
  echo "🛑 Arrêt du serveur..."\n\
  kill $XVFB_PID\n\
  exit 0\n\
}\n\
\n\
# Gestion des signaux d\'arrêt\n\
trap cleanup SIGINT SIGTERM\n\
\n\
# Lancement du jeu avec Proton\n\
cd ${USER_HOME}/sunkenland\n\
${USER_HOME}/.steam/root/compatibilitytools.d/${PROTON_VERSION}/proton run Sunkenland.exe $ARGS\n\
\n\
# Maintenir le conteneur en vie\n\
wait $XVFB_PID\n\
' > ${USER_HOME}/start.sh && chmod +x ${USER_HOME}/start.sh

# Exposition du port du serveur
EXPOSE ${SERVER_PORT}/udp

# Volume pour les mondes personnalisés
VOLUME ["${USER_HOME}/worlds"]

# Point d'entrée
ENTRYPOINT ["./start.sh"]