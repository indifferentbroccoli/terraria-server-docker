#!/bin/bash
# Exit 0 = healthy, Exit 1 = unhealthy

set -euo pipefail

GAME_PORT="${GAME_PORT:-7777}"
TMODLOADER_ENABLED="${TMODLOADER_ENABLED:-false}"
HEALTHCHECK_VERBOSE="${HEALTHCHECK_VERBOSE:-false}"
BOOT_GRACE_SECONDS="${BOOT_GRACE_SECONDS:-300}"

# Touched on first successful process detection — distinguishes "still booting" from "crashed"
BOOT_SENTINEL="/tmp/.terraria-healthcheck-booted"

log() {
  if [ "$HEALTHCHECK_VERBOSE" = "true" ]; then
    echo "[healthcheck] $1"
  fi
}

fail() {
  echo "[healthcheck] FAIL: $1" >&2
  exit 1
}

container_uptime() {
  local pid1_start
  pid1_start=$(stat -c %Y /proc/1 2>/dev/null || echo "0")
  local now
  now=$(date +%s)
  echo $(( now - pid1_start ))
}

# Is the game server binary running?
check_process() {
  log "Checking server process..."

  if [ "$TMODLOADER_ENABLED" = "true" ]; then
    if pgrep -f "dotnet|tModLoader|ScriptCaller" > /dev/null 2>&1; then
      log "  tModLoader process found"
      return 0
    fi
  else
    if pgrep -f "TerrariaServer" > /dev/null 2>&1; then
      log "  TerrariaServer process found"
      return 0
    fi
  fi

  return 1
}

# Process + boot state: still booting vs crashed vs stuck
check_boot_state() {
  log "Checking boot state..."

  local uptime
  uptime=$(container_uptime)

  if check_process; then
    if [ ! -f "$BOOT_SENTINEL" ]; then
      touch "$BOOT_SENTINEL"
      log "  Boot sentinel created"
    fi
    return 0
  fi

  # Process not running — was it ever?
  if [ -f "$BOOT_SENTINEL" ]; then
    fail "Server process was previously running but is no longer detected (likely crashed)"
  fi

  if [ "$uptime" -lt "$BOOT_GRACE_SECONDS" ]; then
    log "  Within boot grace period (${uptime}s / ${BOOT_GRACE_SECONDS}s)"
    return 0
  fi

  fail "Server process not found after ${BOOT_GRACE_SECONDS}s — likely stuck on boot error"
}

# Is GAME_PORT actually being listened on?
check_port_listening() {
  log "Checking port ${GAME_PORT} listener..."

  if command -v ss > /dev/null 2>&1; then
    if ss -tlnp 2>/dev/null | grep -q ":${GAME_PORT} "; then
      log "  Port ${GAME_PORT} is listening"
      return 0
    fi
  elif command -v netstat > /dev/null 2>&1; then
    if netstat -tlnp 2>/dev/null | grep -q ":${GAME_PORT} "; then
      log "  Port ${GAME_PORT} is listening"
      return 0
    fi
  else
    # Fallback: parse /proc/net/tcp directly
    local hex_port
    hex_port=$(printf '%04X' "$GAME_PORT")
    if grep -qi ":${hex_port} " /proc/net/tcp 2>/dev/null; then
      log "  Port ${GAME_PORT} is listening"
      return 0
    fi
  fi

  return 1
}

# Can a client actually TCP connect?
check_tcp_connect() {
  log "Probing TCP connection to localhost:${GAME_PORT}..."

  if command -v curl > /dev/null 2>&1; then
    if curl -sf --connect-timeout 3 "telnet://localhost:${GAME_PORT}" > /dev/null 2>&1; then
      log "  TCP connect succeeded"
      return 0
    fi
  fi

  if timeout 3 bash -c "echo > /dev/tcp/localhost/${GAME_PORT}" 2>/dev/null; then
    log "  TCP connect succeeded"
    return 0
  fi

  return 1
}

# Fail if critically low on memory
check_resources() {
  log "Checking available memory..."

  local mem_available_kb
  mem_available_kb=$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
  local mem_available_mb=$(( mem_available_kb / 1024 ))

  if [ "$mem_available_mb" -lt 50 ]; then
    fail "Critically low memory: ${mem_available_mb}MB available"
  fi

  log "  Memory OK: ${mem_available_mb}MB available"
  return 0
}

# Soft check — FIFO missing won't fail, but means console commands won't work
check_fifo() {
  log "Checking command FIFO..."

  if [ -p "/tmp/terraria-stdin" ]; then
    log "  FIFO intact"
    return 0
  fi

  log "  WARNING: FIFO /tmp/terraria-stdin missing"
  return 0
}

main() {
  log "=== Health check starting ==="

  check_boot_state

  # Still booting — skip remaining checks
  if ! check_process; then
    log "=== HEALTHY (booting) ==="
    exit 0
  fi

  if ! check_port_listening; then
    fail "Process running but port ${GAME_PORT} is NOT listening"
  fi

  if ! check_tcp_connect; then
    fail "Port ${GAME_PORT} listening but TCP connection failed"
  fi

  check_resources
  check_fifo

  log "=== HEALTHY ==="
  exit 0
}

main