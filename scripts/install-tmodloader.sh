#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/terraria/server/functions.sh"

LogAction "Installing tModLoader"

# Resolve version
TMOD_VERSION="${TMODLOADER_VERSION:-latest}"
if [ "${TMOD_VERSION}" = "latest" ]; then
    LogInfo "Fetching latest tModLoader version..."
    TMOD_VERSION=$(curl -s "https://api.github.com/repos/tModLoader/tModLoader/releases/latest" \
        | grep '"tag_name"' \
        | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
    if [ -z "$TMOD_VERSION" ]; then
        LogError "Failed to fetch latest tModLoader version"
        exit 1
    fi
fi

LogInfo "Installing tModLoader version: ${TMOD_VERSION}"

download_url="https://github.com/tModLoader/tModLoader/releases/download/${TMOD_VERSION}/tModLoader.zip"
tmp_zip="/tmp/tmodloader.zip"
tmp_extract="/tmp/tmodloader-extract"

if ! wget -q --show-progress -O "${tmp_zip}" "${download_url}"; then
    LogError "Failed to download tModLoader ${TMOD_VERSION}"
    exit 1
fi

LogInfo "Extracting tModLoader files"
rm -rf "${tmp_extract}"
if ! unzip -q -o "${tmp_zip}" -d "${tmp_extract}"; then
    LogError "Failed to extract tModLoader files"
    exit 1
fi

# Find the server start script
server_script=$(find "${tmp_extract}" -name "start-tModLoaderServer.sh" | head -1)
if [ -z "${server_script}" ]; then
    LogError "Could not find start-tModLoaderServer.sh in the tModLoader zip"
    exit 1
fi
src_dir=$(dirname "${server_script}")
LogInfo "Copying from: ${src_dir}"
cp -rf "${src_dir}/." /terraria/
chmod +x /terraria/start-tModLoaderServer.sh

mkdir -p /terraria/mods /terraria/worlds
chown -R terraria:terraria /terraria

rm -rf "${tmp_zip}" "${tmp_extract}"

LogSuccess "tModLoader ${TMOD_VERSION} installed successfully"
