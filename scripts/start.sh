#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/terraria/server/functions.sh"

cd /terraria || exit

# if GENERATE_SETTINGS IS FALSE then we will not generate the settings
if [ "$GENERATE_SETTINGS" = "true" ]; then
  LogAction "Compiling server settings"
  /home/terraria/server/compile-server-settings.sh
elif [ "$GENERATE_SETTINGS" = "false" ]; then
  LogWarn "GENERATE_SETTINGS=false, not overwriting settings"
fi

# Ensure terraria user owns all data dirs (compile scripts run as root)
chown -R terraria:terraria /terraria

LogAction "Starting server"
if [ "${TMODLOADER_ENABLED:-false}" = "true" ]; then
  su terraria -c "/terraria/start_tModLoaderServer.sh \
    -server \
    -config /terraria/serverconfig.txt \
    -port ${GAME_PORT} \
    -ip ${SERVER_IP} \
    -modpath /terraria/mods"
else
  su terraria -c "/terraria/TerrariaServer.bin.x86_64 \
    -config /terraria/serverconfig.txt \
    -port ${GAME_PORT} \
    -ip ${SERVER_IP}"
fi
