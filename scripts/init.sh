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

export FIFO_PATH=/tmp/terraria-stdin
mkfifo "$FIFO_PATH"

# Keep FIFO open so the server never receives EOF
sleep infinity > "$FIFO_PATH" &
export SLEEP_PID=$!

# Start the server with the FIFO as stdin
./start.sh < "$FIFO_PATH" &
killpid=$!

# Wait briefly for the server process to start, then capture its PID
sleep 3
export SERVER_PID=$(pgrep -f "TerrariaServer.bin.x86_64\|tModLoaderServer" 2>/dev/null | head -1 || echo "")

trap 'shutdown_gracefully' SIGTERM SIGINT

wait "$killpid"
