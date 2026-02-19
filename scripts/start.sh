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
  rm -f /tmp/.X99-lock
  Xvfb :99 -screen 0 1x1x8 &
  export DISPLAY=:99
  chmod +x /terraria/LaunchUtils/ScriptCaller.sh
  /terraria/LaunchUtils/ScriptCaller.sh -config /terraria/serverconfig.txt -tmlsavedirectory /terraria -server
else
  /terraria/TerrariaServer.bin.x86_64 -config /terraria/serverconfig.txt
fi
