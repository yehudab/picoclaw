#!/bin/sh
# StatusCake Push (heartbeat) monitor for the picoclaw bot stack.
#
# Pings the StatusCake Push URL ONLY when the stack is healthy:
#   1. picoclaw-gateway container is running AND Docker health = healthy
#   2. the gateway can reach the scorer at http://scorer:5000/health
#
# When a check fails we deliberately DO NOT ping, so StatusCake sees the
# heartbeat stop and alerts. Set the StatusCake Push monitor's period longer
# than the cron interval (e.g. cron every 5m, period ~15m) so a single
# transient miss doesn't false-alarm but a real outage does.
#
# The Push URL is a secret; it's read from a file kept OUTSIDE the repo.
# Installed via /etc/cron.d/picoclaw-heartbeat (runs as root).

set -eu

PUSH_URL_FILE="/home/ubuntu/.statuscake_push_url"
LOG="/home/ubuntu/picoclaw/docker/data/logs/statuscake_heartbeat.log"

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $1" >>"$LOG" 2>/dev/null || true; }

[ -r "$PUSH_URL_FILE" ] || { log "FAIL: push URL file $PUSH_URL_FILE missing/unreadable"; exit 1; }
PUSH_URL="$(cat "$PUSH_URL_FILE")"
[ -n "$PUSH_URL" ] || { log "FAIL: push URL file is empty"; exit 1; }

# 1) container running + Docker-healthy
state="$(docker inspect -f '{{.State.Status}}:{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' picoclaw-gateway 2>/dev/null || echo missing)"
if [ "$state" != "running:healthy" ]; then
	log "DOWN: gateway state=$state (heartbeat withheld)"
	exit 0
fi

# 2) gateway -> scorer reachability (the failure that broke image scoring)
if ! docker exec picoclaw-gateway wget -q -T 5 -O /dev/null http://scorer:5000/health 2>/dev/null; then
	log "DOWN: gateway cannot reach scorer:5000 (heartbeat withheld)"
	exit 0
fi

# healthy -> send heartbeat
if curl -fsS -m 10 "$PUSH_URL" >/dev/null 2>&1; then
	log "OK: heartbeat sent"
else
	log "WARN: checks passed but push to StatusCake failed"
fi
