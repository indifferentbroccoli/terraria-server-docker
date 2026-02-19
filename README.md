[![GitHub License](https://img.shields.io/github/license/indifferentbroccoli/terraria-server-docker?style=for-the-badge&color=6aa84f)](https://github.com/indifferentbroccoli/terraria-server-docker/blob/main/LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/indifferentbroccoli/terraria-server-docker?style=for-the-badge&color=6aa84f)](https://github.com/indifferentbroccoli/terraria-server-docker/releases)
[![GitHub Repo stars](https://img.shields.io/github/stars/indifferentbroccoli/terraria-server-docker?style=for-the-badge&color=6aa84f)](https://github.com/indifferentbroccoli/terraria-server-docker)
[![Discord](https://img.shields.io/discord/798321161082896395?style=for-the-badge&label=Discord&labelColor=5865F2&color=6aa84f)](https://discord.gg/indifferentbroccoli)
[![Docker Pulls](https://img.shields.io/docker/pulls/indifferentbroccoli/terraria-server-docker?style=for-the-badge&color=6aa84f)](https://hub.docker.com/r/indifferentbroccoli/terraria-server-docker)

Game server hosting

Fast RAM, high-speed internet

Eat lag for breakfast

[Try our Terraria Server hosting free for 2 days!](https://indifferentbroccoli.com/terraria-server-hosting)

# Terraria Server Docker

## Server Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU      | Dual-core x86/64 processor | Quad-core or better |
| RAM      | 1GB     | 2GB+        |
| Storage  | 1GB     | 2GB         |

## How to use

Copy the `.env.example` file to a new file called `.env`. Then use either `docker compose` or `docker run`.

### Docker compose

Starting the server with Docker Compose:

```yaml
services:
  terraria:
    image: indifferentbroccoli/terraria-server-docker
    restart: unless-stopped
    container_name: terraria
    stop_grace_period: 30s
    ports:
      - '7777:7777/tcp'
    environment:
      PUID: 1000
      PGID: 1000
    env_file:
      - .env
    volumes:
      - ./terraria:/terraria
```

Then run:

```bash
docker-compose up -d
```

### Docker Run

```bash
docker run -d \
    --restart unless-stopped \
    --name terraria \
    --stop-timeout 30 \
    -p 7777:7777/tcp \
    -e PUID=1000 \
    -e PGID=1000 \
    -e TERRARIA_VERSION=1450 \
    --env-file .env \
    -v ./terraria:/terraria \
    indifferentbroccoli/terraria-server-docker
```

## Environment Variables

### Container settings

| Variable            | Default  | Description                              |
|---------------------|----------|------------------------------------------|
| `PUID`              | `1000`   | User ID to run the server as             |
| `PGID`              | `1000`   | Group ID to run the server as            |
| `TERRARIA_VERSION`  | `1450`   | Terraria version to download and install (e.g. `1450` for 1.4.5.0) |

### Server settings

| Variable          | Default                    | Description                                               |
|-------------------|----------------------------|-----------------------------------------------------------|
| `GAME_PORT`       | `7777`                     | Game port (TCP)                                           |
| `SERVER_IP`       | `0.0.0.0`                  | Server bind IP                                            |
| `MAX_PLAYERS`     | `8`                        | Maximum number of players                                 |
| `SERVER_PASSWORD` |                            | Server password (leave empty for no password)             |
| `MOTD`            | `Welcome to the server!`   | Message of the day shown to connecting players            |
| `WORLD_NAME`      | `World`                    | World name (also used as filename)                        |
| `AUTOCREATE`      | `2`                        | Auto-create world size: `1` = small, `2` = medium, `3` = large |
| `DIFFICULTY`      | `0`                        | World difficulty: `0` = normal, `1` = expert, `2` = master, `3` = journey |
| `SEED`            |                            | World seed (leave empty for random)                       |
| `SECURE`          | `1`                        | Enable VAC-style cheat protection (`0` or `1`)            |
| `LANGUAGE`        | `en-US`                    | Server language                                           |
| `UPNP`            | `0`                        | Enable UPnP (`0` or `1`)                                  |
| `NPCSTREAM`       | `60`                       | Reduce enemy skipping on low bandwidth (`0`–`60`)         |
| `PRIORITY`        | `1`                        | Process priority (`0`–`5`, `1` = high)                    |

## tModLoader

tModLoader support is fully automated. Set `TMODLOADER_ENABLED=true` to download and run tModLoader instead of the vanilla server. When enabled, the vanilla Terraria install is skipped entirely — tModLoader is a standalone dedicated server.

> [!WARNING]
> **The `./terraria` folder must be empty (or not exist) when first enabling tModLoader.**
> tModLoader installs its own binaries and libraries (including `FNA.dll`) into `/terraria`. If the folder already contains a vanilla Terraria install, the wrong `FNA.dll` will be loaded and the server will crash.
> Delete or clear `./terraria` before switching between vanilla and tModLoader.

### tModLoader settings

| Variable              | Default  | Description                                                                 |
|-----------------------|----------|-----------------------------------------------------------------------------|
| `TMODLOADER_ENABLED`  | `false`  | Set to `true` to run tModLoader instead of vanilla Terraria                 |
| `TMODLOADER_VERSION`  | `latest` | tModLoader version tag to install (e.g. `v2024.11.3`). `latest` auto-resolves from GitHub |

### Steam Workshop mods

Set `WORKSHOP_MODS` to a comma-separated list of Steam Workshop mod IDs. Mods are downloaded automatically on every startup using SteamCMD and installed to `/terraria/mods`.

```dotenv
TMODLOADER_ENABLED=true
WORKSHOP_MODS=2824688072,2835214226,1213059773
```

The mod IDs can be found in the Steam Workshop URL:
`https://steamcommunity.com/sharedfiles/filedetails/?id=`**`2824688072`**

Mods are persisted in `./terraria/mods` and updated on each container start. An `enabled.json` is automatically generated from your `WORKSHOP_MODS` list so tModLoader loads them without any manual configuration.

## Sending commands to the server

Attach to the server console to type commands directly:

```bash
docker attach terraria
```

Detach without stopping the server with `Ctrl+P` then `Ctrl+Q`.

### Examples

```
say Hello everyone!
kick PlayerName
save
exit
```
