# Sunkenland Proton Server

Serveur dedie Sunkenland (version Windows) sous Proton GE, dans Docker.

## Lancement

1. Copier le dossier du monde (`Sunkenworld~<guid>`) dans `worlds/`.
2. Renseigner `GAME_WORLD_GUID` dans `docker-compose.yml`.
3. `cp .env.example .env` puis y mettre `GAME_PASSWORD` (8 caracteres max).
4. `docker compose up -d --build`

Le jeu est telecharge au premier demarrage dans le volume `game`, puis mis a jour a chaque demarrage si `GAME_AUTO_UPDATE=true`.

## Variables

| Variable | Defaut | Description |
|---|---|---|
| `GAME_WORLD_GUID` | | GUID du monde (partie apres `~`), obligatoire |
| `GAME_PASSWORD` | | Mot de passe, 8 caracteres max |
| `GAME_REGION` | `eu` | asia, cn, jp, eu, sa, kr, us, usw |
| `GAME_MAX_PLAYER` | `10` | Entre 3 et 15 |
| `GAME_SESSION_INVISIBLE` | `false` | Cache le serveur de la liste publique |
| `GAME_AUTO_UPDATE` | `true` | Mise a jour via SteamCMD a chaque demarrage |

## Logs

`docker compose logs -f`
