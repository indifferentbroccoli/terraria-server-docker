#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/terraria/server/functions.sh"

if [ -z "${WORKSHOP_MODS:-}" ]; then
    LogInfo "No workshop mods specified, skipping mod download"
    exit 0
fi

MODS_DIR="/terraria/mods"
WORKSHOP_CONTENT="/root/Steam/steamapps/workshop/content/1281930"

mkdir -p "${MODS_DIR}"

IFS=',' read -ra MOD_IDS <<< "${WORKSHOP_MODS}"

for MOD_ID in "${MOD_IDS[@]}"; do
    MOD_ID=$(echo "$MOD_ID" | tr -d ' ')
    [ -z "$MOD_ID" ] && continue

    LogInfo "Downloading workshop mod: ${MOD_ID}"
    if ! /usr/local/steamcmd/steamcmd.sh \
        +@ShutdownOnFailedCommand 1 \
        +@NoPromptForPassword 1 \
        +login anonymous \
        +workshop_download_item 1281930 "${MOD_ID}" validate \
        +quit; then
        LogWarn "SteamCMD reported an error for mod ${MOD_ID}, continuing..."
    fi

    mod_path="${WORKSHOP_CONTENT}/${MOD_ID}"
    if [ -d "${mod_path}" ]; then
        find "${mod_path}" -name "*.tmod" -exec cp -f {} "${MODS_DIR}/" \;
        LogSuccess "Mod ${MOD_ID} installed"
    else
        LogWarn "Could not find downloaded mod ${MOD_ID} at ${mod_path}"
    fi
done

chown -R terraria:terraria "${MODS_DIR}"
LogSuccess "Workshop mod installation complete"
