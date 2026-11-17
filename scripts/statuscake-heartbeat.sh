#!/bin/sh
# StatusCake Push (heartbeat) monitor for the picoclaw bot stack.
#
# Pings the StatusCake Push URL ONLY when the stack is healthy:
#   1. picoclaw-gateway container is running AND Docker health = healthy
#   2. the gateway can reach the scorer at http://scorer:5000/health
#   3. WhatsApp is not in a failed state, detected by EITHER of:
#        (a) a WhatsApp error (e.g. 405 "Client outdated", server-side logout) in
#            the container log within WA_ERR_LOOKBACK, OR
#        (b) no recent "WhatsApp alive" line in gateway.log. The channel logs it
#            every 5 min while whatsmeow is connected AND logged in, so it doesn't
#            depend on chat traffic. (a) catches known failures instantly; (b)
#            catches everything else and holds the alert until WhatsApp is back.
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

# 3a) a known WhatsApp failure in the container log:
#     - a whatsmeow error, e.g. 405 "Client outdated" when whatsmeow falls behind
#       WhatsApp's required client version. whatsmeow logs to its OWN stdout
#       (waLog.Stdout), i.e. only to `docker logs`, never to gateway.log.
#     - picoclaw's "WhatsApp logged out" (events.LoggedOut) or a reconnect error
#       with "invalid use of deleted device" (server-side logout / device removed).
#     NB: plain "reconnect failed" is deliberately NOT matched any more. It mostly
#     came from a benign race with whatsmeow's auto-reconnect ("websocket is
#     already connected"), which kept the heartbeat withheld forever. 3b covers
#     real reconnect failures.
WA_ERR_LOOKBACK="60m"
if docker logs --since "$WA_ERR_LOOKBACK" picoclaw-gateway 2>&1 | grep -aqE 'WhatsApp ERROR|Client outdated|WhatsApp logged out|invalid use of deleted device'; then
	log "DOWN: WhatsApp error in container log within $WA_ERR_LOOKBACK (heartbeat withheld)"
	exit 0
fi

# 3b) positive liveness: the newest "WhatsApp alive" line in gateway.log must be
#     younger than WA_ALIVE_MAX_AGE_SECS (logged every 5 min -> 12 min allows one
#     missed tick plus cron jitter). After a gateway restart the first alive line
#     comes ~5 min in, well within one StatusCake period.
#     Fallback: if gateway.log has NO alive line at all (a build older than the
#     alive ticker), use the old staleness check (log untouched > 900s) instead.
WA_ALIVE_MAX_AGE_SECS=720
WA_LOG_STALE_SECS=900
GATEWAY_LOG="/home/ubuntu/picoclaw/docker/data/logs/gateway.log"

# age in seconds of the "time" field of a gateway.log JSON line on stdin (empty if none)
line_age() {
	ts="$(grep -oE '"time":"[^"]*"' | head -1 | cut -d'"' -f4)"
	[ -n "$ts" ] || return 0
	echo $(( $(date -u +%s) - $(date -u -d "$ts" +%s 2>/dev/null || echo 0) ))
}

alive_age="$(grep -a '"message":"WhatsApp alive"' "$GATEWAY_LOG" 2>/dev/null | tail -1 | line_age)"
if [ -n "$alive_age" ]; then
	if [ "$alive_age" -gt "$WA_ALIVE_MAX_AGE_SECS" ]; then
		log "DOWN: last WhatsApp alive ${alive_age}s ago (>${WA_ALIVE_MAX_AGE_SECS}s) (heartbeat withheld)"
		exit 0
	fi
else
	log_age="$(tail -1 "$GATEWAY_LOG" 2>/dev/null | line_age)"
	if [ -z "$log_age" ]; then
		log "DOWN: gateway.log unreadable/empty (heartbeat withheld)"
		exit 0
	fi
	if [ "$log_age" -gt "$WA_LOG_STALE_SECS" ]; then
		log "DOWN: no alive line yet and gateway.log stale ${log_age}s (>${WA_LOG_STALE_SECS}s) (heartbeat withheld)"
		exit 0
	fi
fi

# healthy -> send heartbeat
if curl -fsS -m 10 "$PUSH_URL" >/dev/null 2>&1; then
	log "OK: heartbeat sent"
else
	log "WARN: checks passed but push to StatusCake failed"
fi
