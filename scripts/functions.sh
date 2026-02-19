#!/bin/bash

#================
# Log Definitions
#================
export LINE='\n'                        # Line Break
export RESET='\033[0m'                  # Text Reset
export WhiteText='\033[0;37m'           # White

# Bold
export RedBoldText='\033[1;31m'         # Red
export GreenBoldText='\033[1;32m'       # Green
export YellowBoldText='\033[1;33m'      # Yellow
export CyanBoldText='\033[1;36m'        # Cyan
#================
# End Log Definitions
#================

LogInfo() {
  Log "$1" "$WhiteText"
}
LogWarn() {
  Log "$1" "$YellowBoldText"
}
LogError() {
  Log "$1" "$RedBoldText"
}
LogSuccess() {
  Log "$1" "$GreenBoldText"
}
LogAction() {
  Log "$1" "$CyanBoldText" "====" "===="
}
Log() {
  local message="$1"
  local color="$2"
  local prefix="$3"
  local suffix="$4"
  printf "$color%s$RESET$LINE" "$prefix$message$suffix"
}

install() {
  LogAction "Starting server install"
  LogInfo "Installing Terraria version: ${TERRARIA_VERSION}"

  local download_url="https://terraria.org/api/download/pc-dedicated-server/terraria-server-${TERRARIA_VERSION}.zip"
  local tmp_zip="/tmp/terraria-server-${TERRARIA_VERSION}.zip"
  local tmp_extract="/tmp/terraria-extract"

  LogInfo "Downloading from: ${download_url}"
  if ! wget -q --show-progress -O "${tmp_zip}" "${download_url}"; then
    LogError "Failed to download Terraria server version ${TERRARIA_VERSION}"
    exit 1
  fi

  LogInfo "Extracting server files"
  rm -rf "${tmp_extract}"
  if ! unzip -q -o "${tmp_zip}" -d "${tmp_extract}"; then
    LogError "Failed to extract Terraria server files"
    exit 1
  fi

  local linux_dir="${tmp_extract}/${TERRARIA_VERSION}/Linux"
  if [ ! -d "${linux_dir}" ]; then
    LogError "Linux server directory not found in extracted zip (expected: ${linux_dir})"
    exit 1
  fi

  cp -r "${linux_dir}/." /terraria/
  chmod +x /terraria/TerrariaServer.bin.x86_64 2>/dev/null || true
  chmod +x /terraria/TerrariaServer 2>/dev/null || true

  chown -R terraria:terraria /terraria

  rm -rf "${tmp_zip}" "${tmp_extract}"

  LogSuccess "Terraria server installed successfully"
}



shutdown_gracefully() {
  set +e
  echo "Shutdown request received. Stopping server gracefully..."

  if [ -n "${SERVER_PID:-}" ] && kill -0 "${SERVER_PID}" 2>/dev/null; then
    echo "save" > "${FIFO_PATH:-/tmp/terraria-stdin}"
    sleep 3
    echo "exit" > "${FIFO_PATH:-/tmp/terraria-stdin}"
    wait "${SERVER_PID}" 2>/dev/null
  fi

  kill "${SLEEP_PID:-}" 2>/dev/null
  echo "Server stopped"
  exit 0
}

memory_check() {
  RAMAVAILABLE=$(awk '/MemAvailable/ {printf( "%d\n", $2 / 1024000 )}' /proc/meminfo)
  if [ "$RAMAVAILABLE" -lt "1" ]; then
    LogWarn "You have less than 1GB of RAM available. This may cause issues with the server."
    return 1
  else
    return 0
  fi
}
