#!/bin/sh
# StatusCake Push (heartbeat) monitor for the picoclaw bot stack.
#
# Pings the StatusCake Push URL ONLY when the stack is healthy:
#   1. picoclaw-gateway container is running AND Docker health = healthy
#   2. the gateway can reach the scorer at http://scorer:5000/health
#   3. WhatsApp is not in a failed state, detected by EITHER of:
#        (a) a WhatsApp error (e.g. 405 "Client outdated") in the container log
#            within WA_ERR_LOOKBACK, OR
#        (b) the gateway JSON log gone stale beyond WA_LOG_STALE_SECS (the silent
#            stall after whatsmeow stops retrying). (a) catches the failure instantly;
#            (b) holds the alert through the silent tail so it doesn't false-recover.
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

# 3a) recent WhatsApp connection error, EITHER:
#     - a whatsmeow error (e.g. 405 "Client outdated" when whatsmeow falls behind
#       WhatsApp's required client version). whatsmeow logs these to its OWN stdout
#       (waLog.Stdout) -> the container log captured by `docker logs`, NOT the JSON
#       file logger, so we must grep the container log here. whatsmeow logs it at
#       connect time then goes quiet, which is why 3b backstops it.
#     - a picoclaw "WhatsApp reconnect failed" line, emitted every ~5m while the
#       channel is stuck retrying (e.g. "invalid use of deleted device" after a
#       server-side logout). This is a warn-level line that 3b MISSES because the
#       retry loop keeps the log fresh forever (dead-but-chatty), so match it here.
WA_ERR_LOOKBACK="60m"
if docker logs --since "$WA_ERR_LOOKBACK" picoclaw-gateway 2>&1 | grep -aqE 'WhatsApp ERROR|Client outdated|reconnect failed'; then
	log "DOWN: WhatsApp error in container log within $WA_ERR_LOOKBACK (heartbeat withheld)"
	exit 0
fi

# 3b) log-staleness backstop: a healthy gateway writes gateway.log at least every
#     ~5 min (WhatsApp activity); when WhatsApp dies and whatsmeow stops retrying the
#     file goes completely silent (observed 80+ min frozen). Threshold has margin over
#     the ~5-min healthy max gap to avoid false alarms.
#     NB: VERIFY this holds after the whatsmeow bump — if the new build's healthy
#     connection is quieter (less reconnect churn), raise WA_LOG_STALE_SECS.
WA_LOG_STALE_SECS=900
GATEWAY_LOG="/home/ubuntu/picoclaw/docker/data/logs/gateway.log"
last_log_ts="$(tail -1 "$GATEWAY_LOG" 2>/dev/null | grep -oE '"time":"[^"]*"' | head -1 | cut -d'"' -f4)"
if [ -z "$last_log_ts" ]; then
	log "DOWN: gateway.log unreadable/empty (heartbeat withheld)"
	exit 0
fi
log_age=$(( $(date -u +%s) - $(date -u -d "$last_log_ts" +%s 2>/dev/null || echo 0) ))
if [ "$log_age" -gt "$WA_LOG_STALE_SECS" ]; then
	log "DOWN: gateway.log stale ${log_age}s (>${WA_LOG_STALE_SECS}s) - process stalled (heartbeat withheld)"
	exit 0
fi

# healthy -> send heartbeat
if curl -fsS -m 10 "$PUSH_URL" >/dev/null 2>&1; then
	log "OK: heartbeat sent"
else
	log "WARN: checks passed but push to StatusCake failed"
fi
