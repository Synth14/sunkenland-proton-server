#!/bin/bash

GAME_DIR="${USER_HOME}/sunkenland"
GAME_EXE="Sunkenland-DedicatedServer.exe"
WORLDS_DIR="${USER_HOME}/worlds"
PROTON_DIR="${USER_HOME}/.steam/root/compatibilitytools.d/${PROTON_VERSION}"

export STEAM_COMPAT_CLIENT_INSTALL_PATH="${USER_HOME}/.steam/root"
export STEAM_COMPAT_DATA_PATH="${USER_HOME}/.steam/root/steamapps/compatdata/${SUNKENLAND_APP_ID}"
export WINEPREFIX="${STEAM_COMPAT_DATA_PATH}/pfx"

if [ -z "$GAME_WORLD_GUID" ]; then
  echo "ERREUR: GAME_WORLD_GUID non defini, le serveur ne peut pas demarrer."
  exit 1
fi

if ! compgen -G "${WORLDS_DIR}/*~${GAME_WORLD_GUID}" > /dev/null; then
  echo "ATTENTION: aucun dossier '*~${GAME_WORLD_GUID}' dans ${WORLDS_DIR}."
fi

if [ ${#GAME_PASSWORD} -gt 8 ]; then
  echo "ATTENTION: GAME_PASSWORD depasse 8 caracteres, le jeu risque de le refuser."
fi

# Installation ou mise a jour du jeu
if [ "$GAME_AUTO_UPDATE" = "true" ] || [ ! -f "${GAME_DIR}/${GAME_EXE}" ]; then
  echo "Installation / mise a jour du serveur..."
  "${USER_HOME}/steamcmd/steamcmd.sh" +@sSteamCmdForcePlatformType windows \
    +force_install_dir "$GAME_DIR" +login anonymous \
    +app_update "$SUNKENLAND_APP_ID" validate +quit
fi

if [ ! -f "${GAME_DIR}/${GAME_EXE}" ]; then
  echo "ERREUR: ${GAME_EXE} introuvable dans ${GAME_DIR}, l'installation a echoue."
  exit 1
fi

# Le jeu lit ses mondes dans le profil Windows du prefixe Proton
WORLD_LINK="${WINEPREFIX}/drive_c/users/steamuser/AppData/LocalLow/Vector3 Studio/Sunkenland/Worlds"
mkdir -p "$(dirname "$WORLD_LINK")"
if [ -d "$WORLD_LINK" ] && [ ! -L "$WORLD_LINK" ]; then
  # Un vrai dossier cree par le jeu: on recupere son contenu avant de le remplacer
  cp -an "$WORLD_LINK"/. "$WORLDS_DIR"/
  rm -rf "$WORLD_LINK"
fi
ln -sfn "$WORLDS_DIR" "$WORLD_LINK"

ARGS=(-nographics -batchmode -logFile - -worldGuid "$GAME_WORLD_GUID" -region "${GAME_REGION:-eu}")
[ -n "$GAME_PASSWORD" ] && ARGS+=(-password "$GAME_PASSWORD")
[ -n "$GAME_MAX_PLAYER" ] && ARGS+=(-maxPlayerCapacity "$GAME_MAX_PLAYER")
[ "$GAME_SESSION_INVISIBLE" = "true" ] && ARGS+=(-makeSessionInvisible true)

# Serveur X virtuel (verrous residuels supprimes en cas de redemarrage du conteneur)
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0
export DISPLAY=:0
Xvfb :0 -screen 0 1024x768x16 -nolisten tcp &
XVFB_PID=$!

cleanup() {
  echo "Arret du serveur..."
  pkill -INT -f "$GAME_EXE"
  for _ in $(seq 1 20); do
    pgrep -f "$GAME_EXE" > /dev/null || break
    sleep 1
  done
  "${PROTON_DIR}/files/bin/wineserver" -k
  kill "$XVFB_PID" 2>/dev/null
  exit 0
}
trap cleanup SIGINT SIGTERM

echo "Demarrage: ${GAME_EXE} ${ARGS[*]//$GAME_PASSWORD/********}"
cd "$GAME_DIR"
"${PROTON_DIR}/proton" run "$GAME_EXE" "${ARGS[@]}" &
wait $!
