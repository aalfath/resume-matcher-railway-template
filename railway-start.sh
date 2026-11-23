#!/usr/bin/env bash
# Railway start script for Resume Matcher.
# - keeps all state on the Railway volume at /app/backend/data,
# - runs the API (127.0.0.1:8000) and the web app (127.0.0.1:3000) as appuser,
# - puts Caddy with a password in front of them on $PORT,
# - exits non-zero if any process stops, so Railway's ON_FAILURE policy restarts it.
set -euo pipefail

DATA_DIR=/app/backend/data
APP_UID=1000
log() { echo "railway-start: $*" >&2; }

if [ "$(id -u)" = "0" ]; then
  mkdir -p "$DATA_DIR"
  # Railway mounts volumes owned by root: hand it to the image's user (appuser).
  find "$DATA_DIR" -xdev \( ! -user "$APP_UID" -o ! -group "$APP_UID" \) -exec chown "$APP_UID:$APP_UID" {} + 2>/dev/null || true
  exec setpriv --reuid="$APP_UID" --regid="$APP_UID" --init-groups env HOME=/home/appuser "$0" "$@"
fi

# ---- checks -----------------------------------------------------------------
pw="${AUTH_PASSWORD:-}"
if [ "${#pw}" -lt 12 ]; then
  log "AUTH_PASSWORD must be set and at least 12 characters; refusing to start an app with no password."
  exit 1
fi
export AUTH_USERNAME="${AUTH_USERNAME:-admin}"
case "$AUTH_USERNAME" in
  *[!A-Za-z0-9._@-]*|"") log "AUTH_USERNAME may only use letters, digits and ._@-"; exit 1 ;;
esac
export PORT="${PORT:-8080}"
case "$PORT" in 3000|8000) log "PORT must not be 3000 or 8000 (used inside the container)"; exit 1 ;; esac

# ---- app settings -------------------------------------------------------------
# PDF export opens the web app with the built-in Chromium; it must reach it
# directly, not through the password front.
export FRONTEND_BASE_URL=http://127.0.0.1:3000
# Every request already passed Caddy's password check and Railway's edge routes
# by host name, so the app's own host guard can accept any host (custom domains
# work with no extra setting). Set ALLOWED_HOSTS to narrow it.
export ALLOWED_HOSTS="${ALLOWED_HOSTS:-*}"
export LLM_PROVIDER="${LLM_PROVIDER:-openai}"
# Empty values would override the app's defaults: drop them.
for v in LLM_MODEL LLM_API_KEY LLM_API_BASE; do
  [ -z "${!v:-}" ] && unset "$v"
done
if [ -z "${LLM_API_KEY:-}" ]; then
  log "LLM_API_KEY is empty: the app opens, but tailoring needs a key (set it here or in the app's Settings)."
fi
export LOG_LEVEL="${LOG_LEVEL:-INFO}"
# Small-plan friendly (Railway Free/Trial: 0.5 GB RAM, 1 vCPU per service).
export MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=192}"

AUTH_PASSWORD_HASH="$(printf '%s' "$pw" | caddy hash-password)"
pw=""

# ---- start ------------------------------------------------------------------
pids=()
stopping=0
on_term() {
  stopping=1
  kill -TERM "${pids[@]}" 2>/dev/null || true
}
trap on_term TERM INT

cd /app/backend
uvlog="$(echo "$LOG_LEVEL" | tr '[:upper:]' '[:lower:]')"
env -u AUTH_PASSWORD -u AUTH_USERNAME \
  python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --log-level "$uvlog" --no-access-log &
api_pid=$!; pids+=("$api_pid")

for i in $(seq 1 180); do
  if curl -fs -o /dev/null http://127.0.0.1:8000/api/v1/health; then
    log "API is up after ${i}s"; break
  fi
  if ! kill -0 "$api_pid" 2>/dev/null; then
    log "the API stopped during startup"; exit 1
  fi
  [ "$stopping" = "1" ] && exit 0
  if [ "$i" = "180" ]; then log "the API did not answer within 180s"; exit 1; fi
  sleep 1
done

cd /app/frontend
env -u AUTH_PASSWORD -u AUTH_USERNAME -u LLM_API_KEY HOSTNAME=127.0.0.1 PORT=3000 node server.js &
web_pid=$!; pids+=("$web_pid")

env -i PATH="$PATH" HOME=/tmp XDG_DATA_HOME=/tmp/caddy XDG_CONFIG_HOME=/tmp/caddy \
  PORT="$PORT" AUTH_USERNAME="$AUTH_USERNAME" AUTH_PASSWORD_HASH="$AUTH_PASSWORD_HASH" \
  caddy run --config /etc/resume-matcher-railway/Caddyfile --adapter caddyfile &
caddy_pid=$!; pids+=("$caddy_pid")
log "Resume Matcher is starting on port $PORT (user $AUTH_USERNAME)"

# Poll rather than `wait -n`, so any child's exit is noticed at once.
while :; do
  for p in "${pids[@]}"; do
    if ! kill -0 "$p" 2>/dev/null; then
      if [ "$stopping" = "1" ]; then
        kill -TERM "${pids[@]}" 2>/dev/null || true; wait 2>/dev/null || true; exit 0
      fi
      code=0; wait "$p" 2>/dev/null || code=$?
      case "$p" in "$api_pid") who=api ;; "$web_pid") who=web ;; *) who=caddy ;; esac
      log "$who stopped unexpectedly (exit $code); stopping the container so Railway restarts it."
      kill -TERM "${pids[@]}" 2>/dev/null || true
      sleep 2
      kill -KILL "${pids[@]}" 2>/dev/null || true
      [ "$code" = "0" ] && code=1
      exit "$code"
    fi
  done
  sleep 2 &
  wait $! 2>/dev/null || true
done
