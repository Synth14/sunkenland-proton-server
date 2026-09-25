#!/bin/bash

# Configuration de l'environnement Proton
export STEAM_COMPAT_CLIENT_INSTALL_PATH="${USER_HOME}/.steam/root"
export STEAM_COMPAT_DATA_PATH="${USER_HOME}/.steam/root/steamapps/compatdata/${SUNKENLAND_APP_ID}"
mkdir -p "$STEAM_COMPAT_DATA_PATH"

# Mise a jour du jeu si demande
if [ "$GAME_AUTO_UPDATE" = "true" ]; then
  echo "Verification des mises a jour du serveur..."
  "${USER_HOME}/steamcmd/steamcmd.sh" +@sSteamCmdForcePlatformType windows +force_install_dir "${USER_HOME}/sunkenland" +login anonymous +app_update "${SUNKENLAND_APP_ID}" validate +quit
fi

# Verification du WorldGUID
if [ -z "$GAME_WORLD_GUID" ]; then
  echo "ERREUR: GAME_WORLD_GUID non defini, le serveur ne peut pas demarrer."
  exit 1
fi

# Lien entre le dossier des mondes et l'emplacement attendu par le jeu
WORLD_PATH="${STEAM_COMPAT_DATA_PATH}/pfx/drive_c/users/steamuser/AppData/LocalLow/Vector3 Studio/Sunkenland/Worlds"
mkdir -p "$(dirname "$WORLD_PATH")"
rm -rf "$WORLD_PATH"
ln -s "${USER_HOME}/worlds" "$WORLD_PATH"

# Construction des arguments de lancement
ARGS=(-nographics -batchmode -worldGuid "$GAME_WORLD_GUID" -region "${GAME_REGION:-eu}")

if [ -n "$GAME_PASSWORD" ]; then
  ARGS+=(-password "$GAME_PASSWORD")
fi

if [ -n "$GAME_MAX_PLAYER" ]; then
  ARGS+=(-maxPlayerCapacity "$GAME_MAX_PLAYER")
fi

if [ "$GAME_SESSION_INVISIBLE" = "true" ]; then
  ARGS+=(-makeSessionInvisible true)
fi

# Serveur X virtuel
export DISPLAY=:0
Xvfb :0 -screen 0 1024x768x16 -ac &
XVFB_PID=$!

cleanup() {
  echo "Arret du serveur..."
  kill "$GAME_PID" "$XVFB_PID" 2>/dev/null
  exit 0
}
trap cleanup SIGINT SIGTERM

echo "Demarrage du serveur Sunkenland: ${ARGS[*]}"
cd "${USER_HOME}/sunkenland"
"${USER_HOME}/.steam/root/compatibilitytools.d/${PROTON_VERSION}/proton" run Sunkenland-DedicatedServer.exe "${ARGS[@]}" &
GAME_PID=$!
wait "$GAME_PID"
