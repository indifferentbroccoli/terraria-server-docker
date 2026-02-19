#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/terraria/server/functions.sh"

FIFO_PATH=/tmp/terraria-stdin

if [ -z "$1" ]; then
    LogError "Usage: send-command.sh <command>"
    exit 1
fi

if [ ! -p "$FIFO_PATH" ]; then
    LogError "Could not run the command. Is the server running?"
    exit 1
fi

echo "$1" > "$FIFO_PATH"
LogSuccess "Command sent: $1"
