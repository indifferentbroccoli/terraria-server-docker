#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/terraria/server/functions.sh"

MODS_DIR="/terraria/mods"
WORKSHOP_CONTENT="${HOME}/Steam/steamapps/workshop/content/1281930"
ENABLED_JSON="${MODS_DIR}/enabled.json"
WORKSHOP_MANIFEST="${MODS_DIR}/.workshop-mods"

mkdir -p "${MODS_DIR}"

# Remove only previously workshop downloaded mods so manually placed mods are preserved
if [ -f "${WORKSHOP_MANIFEST}" ]; then
    while IFS= read -r mod_name; do
        rm -f "${MODS_DIR}/${mod_name}.tmod"
    done < "${WORKSHOP_MANIFEST}"
    rm -f "${WORKSHOP_MANIFEST}"
fi

if [ -z "${WORKSHOP_MODS:-}" ]; then
    LogInfo "No workshop mods specified, skipping mod download"
    echo "[]" > "${ENABLED_JSON}"
    chown -R terraria:terraria "${MODS_DIR}"
    exit 0
fi

IFS=',' read -ra MOD_IDS <<< "${WORKSHOP_MODS}"

enabled_mods=()

for MOD_ID in "${MOD_IDS[@]}"; do
    MOD_ID=$(echo "$MOD_ID" | tr -d ' ')
    [ -z "$MOD_ID" ] && continue

    LogInfo "Downloading workshop mod: ${MOD_ID}"
    if ! /usr/local/steamcmd/steamcmd.sh \
        +@ShutdownOnFailedCommand 1 \
        +@NoPromptForPassword 1 \
        +login anonymous \
        +workshop_download_item 1281930 "${MOD_ID}" validate \
        +quit > /dev/null 2>&1; then
        LogWarn "SteamCMD reported an error for mod ${MOD_ID}, continuing..."
    fi

    mod_path="${WORKSHOP_CONTENT}/${MOD_ID}"
    if [ -d "${mod_path}" ]; then
        newest_dir=$(ls -1 "${mod_path}" | sort -V | tail -1)
        tmod_file=$(find "${mod_path}/${newest_dir}" -name "*.tmod" | head -1)
        if [ -n "${tmod_file}" ]; then
            cp -f "${tmod_file}" "${MODS_DIR}/"
            mod_name=$(basename "${tmod_file}" .tmod)
            enabled_mods+=("${mod_name}")
            LogSuccess "Mod ${mod_name} installed"
        fi
    else
        LogWarn "Could not find downloaded mod ${MOD_ID} at ${mod_path}"
    fi
done

# Write enabled.json so tModLoader actually loads the mods
LogAction "Writing enabled.json"
{
    echo "["
    for i in "${!enabled_mods[@]}"; do
        if [ $i -lt $(( ${#enabled_mods[@]} - 1 )) ]; then
            echo "  \"${enabled_mods[$i]}\","
        else
            echo "  \"${enabled_mods[$i]}\""
        fi
    done
    echo "]"
} > "${ENABLED_JSON}"

LogInfo "enabled.json written with ${#enabled_mods[@]} mod(s):"
cat "${ENABLED_JSON}"

# Save manifest of downloaded mods for cleanup on next run
for mod_name in "${enabled_mods[@]}"; do
    echo "${mod_name}"
done > "${WORKSHOP_MANIFEST}"

chown -R terraria:terraria "${MODS_DIR}"
LogSuccess "Workshop mod installation complete"
