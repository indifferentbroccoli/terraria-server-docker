#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/terraria/server/functions.sh"

cd /terraria || exit

LogAction "Compiling server settings"
/home/terraria/server/compile-server-settings.sh

# Ensure terraria user owns all data dirs (compile scripts run as root)
chown -R terraria:terraria /terraria

LogAction "Starting server"
if [ "${TMODLOADER_ENABLED:-false}" = "true" ]; then
  su terraria -s /bin/bash -c "cd /terraria && ./dotnet/dotnet tModLoader.dll -server -config /terraria/serverconfig.txt -nosteam"
else
  su terraria -s /bin/bash -c "/terraria/TerrariaServer.bin.x86_64 -config /terraria/serverconfig.txt"
fi
