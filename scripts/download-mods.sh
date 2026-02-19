#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/terraria/server/functions.sh"

if [ -z "${WORKSHOP_MODS:-}" ]; then
    LogInfo "No workshop mods specified, skipping mod download"
    exit 0
fi

MODS_DIR="/terraria/mods"
WORKSHOP_CONTENT="${HOME}/Steam/steamapps/workshop/content/1281930"
ENABLED_JSON="${MODS_DIR}/enabled.json"

mkdir -p "${MODS_DIR}"

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
        while IFS= read -r -d '' tmod_file; do
            cp -f "${tmod_file}" "${MODS_DIR}/"
            mod_name=$(basename "${tmod_file}" .tmod)
            enabled_mods+=("${mod_name}")
            LogSuccess "Mod ${mod_name} installed"
        done < <(find "${mod_path}" -name "*.tmod" -print0)
    else
        LogWarn "Could not find downloaded mod ${MOD_ID} at ${mod_path}"
    fi
done

# Write enabled.json so tModLoader actually loads the mods
LogAction "Writing enabled.json"
printf '[\n'  > "${ENABLED_JSON}"
for i in "${!enabled_mods[@]}"; do
    if [ $i -lt $(( ${#enabled_mods[@]} - 1 )) ]; then
        printf '  "%s",\n' "${enabled_mods[$i]}" >> "${ENABLED_JSON}"
    else
        printf '  "%s"\n'  "${enabled_mods[$i]}" >> "${ENABLED_JSON}"
    fi
done
printf ']\n' >> "${ENABLED_JSON}"

LogInfo "enabled.json written with ${#enabled_mods[@]} mod(s):"
cat "${ENABLED_JSON}"

chown -R terraria:terraria "${MODS_DIR}"
LogSuccess "Workshop mod installation complete"
