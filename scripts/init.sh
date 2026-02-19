#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/terraria/server/functions.sh"

LogAction "Set file permissions"

# if the user has not defined a PUID and PGID, throw an error and exit
if [ -z "${PUID}" ] || [ -z "${PGID}" ]; then
    LogError "PUID and PGID not set. Please set these in the environment variables."
    exit 1
else
    usermod -o -u "${PUID}" terraria
    groupmod -o -g "${PGID}" terraria
fi

chown -R terraria:terraria /terraria /home/terraria/

cat /branding

LogAction "Checking for compatibility issues"
if memory_check; then
    LogSuccess "Compatibility checks passed"
fi

if [ "${TMODLOADER_ENABLED:-false}" = "true" ]; then
    /home/terraria/server/install-tmodloader.sh
    /home/terraria/server/download-mods.sh
else
    install
fi

/home/terraria/server/start.sh &
SERVER_PID=$!

trap 'shutdown_gracefully' SIGTERM SIGINT

wait $SERVER_PID
