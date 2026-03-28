#!/bin/bash
# bOSS Universal Health Check
#
# Auto-detects which game server is running, loads the matching
# baseline from scripts/hconf/, and runs tiered checks accordingly.
#
# Exit codes:
#   0 = Online          All tier checks passed
#   1 = Crashed         Was running, process gone
#   2 = Boot Stuck      Past grace period, never started
#   3 = Port Mismatch   Process running, port not listening
#   4 = Unresponsive    Port listening, connection failed
#   5 = Resource Crit   Memory or disk critically low
#   6 = Booting         Within grace period, not ready yet
#   7 = Query Failed    App-level query got no valid response

set -uo pipefail

VERBOSE="${HEALTHCHECK_VERBOSE:-false}"
BOOT_SENTINEL="/tmp/.boss-healthcheck-booted"
RCON_VERIFIED="/tmp/.boss-healthcheck-rcon-verified"
STATE_FILE="${HEALTHCHECK_STATE_FILE:-/tmp/boss-healthcheck-state.json}"
CHECKS_RUN=0
CHECKS_PASSED=0

# Resolve hconf directory relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HCONF_DIR="${SCRIPT_DIR}/hconf"

log() { [ "$VERBOSE" = "true" ] && echo "[healthcheck] $1"; }

# Load config — GAME_ID must be set in the Dockerfile ENV block
if [ -z "${GAME_ID:-}" ]; then
  echo "[healthcheck] FATAL: GAME_ID env var not set. Add ENV GAME_ID=<game> to the Dockerfile." >&2
  exit 2
fi

CONF_PATH="${HCONF_DIR}/${GAME_ID}.conf"

if [ -f "$CONF_PATH" ]; then
  log "Game: ${GAME_ID} — loading ${CONF_PATH}"
  source "$CONF_PATH"
else
  echo "[healthcheck] FATAL: No config found at ${CONF_PATH}" >&2
  echo "[healthcheck] Available configs:" >&2
  ls "${HCONF_DIR}/"*.conf 2>/dev/null | sed 's/.*\//  /' >&2
  exit 2
fi

# State output
container_uptime() {
  local s
  s=$(stat -c %Y /proc/1 2>/dev/null || echo "0")
  echo $(( $(date +%s) - s ))
}

write_state() {
  local status="$1" code="$2" reason="$3"
  cat > "$STATE_FILE" <<EOF
{
  "game_id": "${GAME_ID}",
  "game_name": "${GAME_NAME}",
  "status": "${status}",
  "exit_code": ${code},
  "reason": "${reason}",
  "tier": "${HEALTHCHECK_TIER}",
  "checks_run": ${CHECKS_RUN},
  "checks_passed": ${CHECKS_PASSED},
  "rcon_verified": $([ -f "$RCON_VERIFIED" ] && echo "true" || echo "false"),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "uptime_seconds": $(container_uptime),
  "config": "${CONF_PATH}"
}
EOF
}

exit_status() {
  local status="$1" code="$2" reason="$3"
  write_state "$status" "$code" "$reason"
  log "=== ${status} (exit ${code}): ${reason} ==="
  exit "$code"
}

pass() {
  CHECKS_RUN=$((CHECKS_RUN + 1))
  CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

# BASIC TIER

check_process() {
  [ -z "${PROCESS_PATTERN:-}" ] && return 0
  CHECKS_RUN=$((CHECKS_RUN + 1))
  if pgrep -f "$PROCESS_PATTERN" > /dev/null 2>&1; then
    log "  Process matched: ${PROCESS_PATTERN}"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
    return 0
  fi
  return 1
}

# One-time RCON boot verification
run_rcon_boot_verify() {
  [ "${RCON_BOOT_VERIFY:-false}" != "true" ] && return 0
  [ -f "$RCON_VERIFIED" ] && return 0

  local port="${RCON_PORT:-}"
  [ -z "$port" ] && return 0

  local cmd="${RCON_CMD:-rcon-cli}"
  local test="${RCON_TEST_COMMAND:-status}"
  local pass_var="${RCON_PASSWORD_VAR:-}"
  local rcon_pass=""
  [ -n "$pass_var" ] && rcon_pass="${!pass_var:-}"

  command -v "$cmd" > /dev/null 2>&1 || return 0

  local max="${RCON_BOOT_VERIFY_RETRIES:-5}"
  local delay="${RCON_BOOT_VERIFY_DELAY:-10}"
  local i=0

  while [ "$i" -lt "$max" ]; do
    i=$((i + 1))
    log "  RCON boot verify ${i}/${max}..."

    local result
    if [ -n "$rcon_pass" ]; then
      result=$(timeout 5 "$cmd" -a "127.0.0.1:${port}" -p "$rcon_pass" "$test" 2>/dev/null)
    else
      result=$(timeout 5 "$cmd" -a "127.0.0.1:${port}" "$test" 2>/dev/null)
    fi

    if [ $? -eq 0 ] && [ -n "$result" ]; then
      touch "$RCON_VERIFIED"
      log "  RCON verified — server processing commands"
      return 0
    fi

    [ "$i" -lt "$max" ] && sleep "$delay"
  done

  log "  WARNING: RCON boot verify exhausted ${max} attempts"
  return 0
}

check_boot_state() {
  local uptime
  uptime=$(container_uptime)

  if check_process; then
    if [ ! -f "$BOOT_SENTINEL" ]; then
      touch "$BOOT_SENTINEL"
      log "  First process detection — boot sentinel created"
      run_rcon_boot_verify
    fi
    return 0
  fi

  if [ -f "$BOOT_SENTINEL" ]; then
    exit_status "Crashed" 1 "Process was running but is no longer detected"
  fi

  if [ "$uptime" -lt "${BOOT_GRACE_SECONDS:-300}" ]; then
    exit_status "Booting" 6 "Within grace period (${uptime}s / ${BOOT_GRACE_SECONDS:-300}s)"
  fi

  exit_status "Boot Stuck" 2 "Process not found after ${BOOT_GRACE_SECONDS:-300}s"
}

check_port_listening() {
  [ -z "${PRIMARY_PORT:-}" ] && return 0
  CHECKS_RUN=$((CHECKS_RUN + 1))
  log "  Port check: ${PRIMARY_PORT}/${PRIMARY_PROTOCOL}"

  local found=false
  if [ "${PRIMARY_PROTOCOL:-tcp}" = "tcp" ]; then
    if command -v ss > /dev/null 2>&1; then
      ss -tlnp 2>/dev/null | grep -q ":${PRIMARY_PORT} " && found=true
    elif [ -f /proc/net/tcp ]; then
      grep -qi ":$(printf '%04X' "$PRIMARY_PORT") " /proc/net/tcp 2>/dev/null && found=true
    fi
  else
    if command -v ss > /dev/null 2>&1; then
      ss -ulnp 2>/dev/null | grep -q ":${PRIMARY_PORT} " && found=true
    elif [ -f /proc/net/udp ]; then
      grep -qi ":$(printf '%04X' "$PRIMARY_PORT") " /proc/net/udp 2>/dev/null && found=true
    fi
  fi

  if [ "$found" = "true" ]; then
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
    return 0
  fi
  exit_status "Port Mismatch" 3 "Process running but ${PRIMARY_PROTOCOL} port ${PRIMARY_PORT} not listening"
}

check_memory() {
  CHECKS_RUN=$((CHECKS_RUN + 1))
  local kb
  kb=$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
  local mb=$(( kb / 1024 ))

  if [ "$mb" -lt "${MIN_MEMORY_MB:-50}" ]; then
    exit_status "Resource Critical" 5 "Memory: ${mb}MB available (min ${MIN_MEMORY_MB:-50}MB)"
  fi
  log "  Memory: ${mb}MB available"
  CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

check_disk() {
  [ -z "${DISK_CHECK_PATH:-}" ] && return 0
  [ ! -d "${DISK_CHECK_PATH:-/}" ] && return 0
  CHECKS_RUN=$((CHECKS_RUN + 1))

  local kb
  kb=$(df -k "$DISK_CHECK_PATH" 2>/dev/null | awk 'NR==2{print $4}')
  local mb=$(( ${kb:-0} / 1024 ))

  if [ "$mb" -lt "${MIN_DISK_MB:-100}" ]; then
    exit_status "Resource Critical" 5 "Disk at ${DISK_CHECK_PATH}: ${mb}MB available (min ${MIN_DISK_MB:-100}MB)"
  fi
  log "  Disk: ${mb}MB available at ${DISK_CHECK_PATH}"
  CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

check_fifo() {
  [ "${FIFO_ENABLED:-false}" != "true" ] && return 0
  [ -z "${FIFO_PATH:-}" ] && return 0
  CHECKS_RUN=$((CHECKS_RUN + 1))

  if [ -p "$FIFO_PATH" ]; then
    log "  FIFO intact: ${FIFO_PATH}"
  else
    log "  WARNING: FIFO missing at ${FIFO_PATH}"
  fi
  # Soft — never fails the check
  CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

# FULL TIER

check_tcp_connect() {
  [ "${PRIMARY_PROTOCOL:-}" != "tcp" ] && return 0
  [ -z "${PRIMARY_PORT:-}" ] && return 0
  CHECKS_RUN=$((CHECKS_RUN + 1))
  log "  TCP probe: localhost:${PRIMARY_PORT}"

  if timeout 3 bash -c "echo > /dev/tcp/localhost/${PRIMARY_PORT}" 2>/dev/null; then
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
    return 0
  fi
  exit_status "Unresponsive" 4 "TCP connect to port ${PRIMARY_PORT} failed"
}

check_steam_query() {
  [ "${STEAM_QUERY_ENABLED:-false}" != "true" ] && return 0
  local port="${STEAM_QUERY_PORT:-}"
  [ -z "$port" ] && return 0
  CHECKS_RUN=$((CHECKS_RUN + 1))
  log "  Steam A2S_INFO: UDP ${port}"

  # Try perl first — available in most slim containers
  if command -v perl > /dev/null 2>&1; then
    timeout 5 perl -e '
      use IO::Socket::INET;
      my $sock = IO::Socket::INET->new(
        PeerAddr => "127.0.0.1",
        PeerPort => $ARGV[0],
        Proto    => "udp",
        Timeout  => 3,
      ) or exit 1;
      # A2S_INFO packet
      my $packet = "\xff\xff\xff\xff\x54Source Engine Query\x00";
      $sock->send($packet) or exit 1;
      my $data;
      eval {
        local $SIG{ALRM} = sub { die "timeout" };
        alarm 3;
        $sock->recv($data, 4096);
        alarm 0;
      };
      exit(length($data) > 5 ? 0 : 1);
    ' "$port" 2>/dev/null
    if [ $? -eq 0 ]; then
      log "  Steam query responded (perl)"
      CHECKS_PASSED=$((CHECKS_PASSED + 1))
      return 0
    fi
  fi

  # Fallback: verify port is bound via /proc/net/udp 
  local hex_port
  hex_port=$(printf '%04X' "$port")
  if grep -qi ":${hex_port} " /proc/net/udp 2>/dev/null; then
    log "  Steam query port bound (no perl/python3 for full A2S)"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
    return 0
  fi

  exit_status "Query Failed" 7 "Steam query on UDP ${port} — no response"
}

# DELUXE TIER

check_https_api() {
  [ "${API_HEALTH_ENABLED:-false}" != "true" ] && return 0
  local url="${API_HEALTH_URL:-}"
  [ -z "$url" ] && return 0
  CHECKS_RUN=$((CHECKS_RUN + 1))
  log "  HTTPS API: ${url}"

  command -v curl > /dev/null 2>&1 || { pass; return 0; }

  local flags=""
  [ "${API_HEALTH_INSECURE:-false}" = "true" ] && flags="-k"

  local code
  if [ "${API_HEALTH_METHOD:-GET}" = "POST" ] && [ -n "${API_HEALTH_BODY:-}" ]; then
    code=$(curl -sf --connect-timeout 5 --max-time 10 $flags \
      -X POST -H "Content-Type: application/json" \
      -d "${API_HEALTH_BODY}" \
      -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
  else
    code=$(curl -sf --connect-timeout 5 --max-time 10 $flags \
      -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
  fi

  if [ "${code:-0}" -ge 200 ] && [ "${code:-0}" -lt 400 ]; then
    log "  API responded HTTP ${code}"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
    return 0
  fi
  exit_status "Query Failed" 7 "HTTPS API returned HTTP ${code:-timeout}"
}

check_builtin_status() {
  [ -z "${BUILTIN_STATUS_CMD:-}" ] && return 0
  CHECKS_RUN=$((CHECKS_RUN + 1))
  log "  Built-in: ${BUILTIN_STATUS_CMD}"

  local result
  if [ -n "${BUILTIN_STATUS_USER:-}" ] && command -v su > /dev/null 2>&1; then
    result=$(timeout 15 su -s /bin/bash "$BUILTIN_STATUS_USER" -c "$BUILTIN_STATUS_CMD" 2>/dev/null)
  else
    result=$(timeout 15 $BUILTIN_STATUS_CMD 2>/dev/null)
  fi

  if [ $? -eq 0 ]; then
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
    return 0
  fi
  exit_status "Query Failed" 7 "Built-in command '${BUILTIN_STATUS_CMD}' failed"
}

check_world_file() {
  [ "${WORLD_FILE_CHECK:-false}" != "true" ] && return 0
  [ -z "${WORLD_FILE_PATTERN:-}" ] && return 0
  CHECKS_RUN=$((CHECKS_RUN + 1))

  # shellcheck disable=SC2086
  local found
  found=$(find $(dirname "$WORLD_FILE_PATTERN") -name "$(basename "$WORLD_FILE_PATTERN")" -size +0c 2>/dev/null | head -1)

  if [ -n "$found" ]; then
    log "  World file: ${found}"
  else
    log "  WARNING: No world file matching ${WORLD_FILE_PATTERN}"
  fi
  # Soft — world may not exist on first boot
  CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

# MAIN
main() {
  log "=== bOSS Health Check ==="
  log "  Game: ${GAME_NAME} (${GAME_ID})"
  log "  Tier: ${HEALTHCHECK_TIER}"
  log "  Config: ${CONF_PATH}"

  # --- BASIC (all games) ---
  check_boot_state
  check_port_listening
  check_memory
  check_disk
  check_fifo

  # --- FULL ---
  if [ "$HEALTHCHECK_TIER" = "full" ] || [ "$HEALTHCHECK_TIER" = "deluxe" ]; then
    check_tcp_connect
    check_steam_query
  fi

  # --- DELUXE ---
  if [ "$HEALTHCHECK_TIER" = "deluxe" ]; then
    check_https_api
    check_builtin_status
    check_world_file
  fi

  exit_status "Online" 0 "All checks passed (${CHECKS_PASSED}/${CHECKS_RUN})"
}

main