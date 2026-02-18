#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/terraria/server/functions.sh"

config_file="/terraria/serverconfig.txt"

mkdir -p /terraria/worlds || exit

export MAX_PLAYERS=${MAX_PLAYERS:-8}
export SERVER_PASSWORD=${SERVER_PASSWORD:-}
export MOTD=${MOTD:-"Welcome to the server!"}
export WORLD_NAME=${WORLD_NAME:-World}
export AUTOCREATE=${AUTOCREATE:-2}
export DIFFICULTY=${DIFFICULTY:-0}
export SEED=${SEED:-}
export SECURE=${SECURE:-1}
export LANGUAGE=${LANGUAGE:-en-US}
export UPNP=${UPNP:-0}
export NPCSTREAM=${NPCSTREAM:-60}
export PRIORITY=${PRIORITY:-1}

cat > "$config_file" <<EOF
$(envsubst < /home/terraria/server/templates/serverconfig.txt.template)
EOF

chown terraria:terraria "$config_file"
