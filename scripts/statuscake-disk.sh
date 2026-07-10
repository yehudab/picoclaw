#!/bin/sh
# StatusCake Push (heartbeat) monitor for free disk space on the host.
#
# Pings the StatusCake Push URL ONLY when the root filesystem has at least
# MIN_FREE_PCT free (default 10%). When free space drops below the threshold
# we deliberately DO NOT ping, so StatusCake sees the heartbeat stop and
# alerts. Set the StatusCake Push monitor's period longer than the cron
# interval (e.g. cron every 5m, period ~15m) so a single transient miss
# doesn't false-alarm but a real low-disk condition does.
#
# The Push URL is a secret; it's read from a file kept OUTSIDE the repo.
# Installed via /etc/cron.d/picoclaw-disk (runs as root).

set -eu

PUSH_URL_FILE="/home/ubuntu/.statuscake_disk_push_url"
LOG="/home/ubuntu/picoclaw/docker/data/logs/statuscake_disk.log"
MIN_FREE_PCT=10
MOUNT="/"

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $1" >>"$LOG" 2>/dev/null || true; }

[ -r "$PUSH_URL_FILE" ] || { log "FAIL: push URL file $PUSH_URL_FILE missing/unreadable"; exit 1; }
PUSH_URL="$(cat "$PUSH_URL_FILE")"
[ -n "$PUSH_URL" ] || { log "FAIL: push URL file is empty"; exit 1; }

# Used% from the Capacity column of `df -P` (portable), free% = 100 - used%.
used_pct="$(df -P "$MOUNT" | awk 'NR==2 {gsub(/%/,"",$5); print $5}')"
case "$used_pct" in
	''|*[!0-9]*) log "FAIL: could not parse df output for $MOUNT (heartbeat withheld)"; exit 1 ;;
esac
free_pct=$((100 - used_pct))

if [ "$free_pct" -lt "$MIN_FREE_PCT" ]; then
	log "DOWN: only ${free_pct}% free on $MOUNT (< ${MIN_FREE_PCT}%, heartbeat withheld)"
	exit 0
fi

# enough free space -> send heartbeat
if curl -fsS -m 10 "$PUSH_URL" >/dev/null 2>&1; then
	log "OK: heartbeat sent (${free_pct}% free)"
else
	log "WARN: ${free_pct}% free but push to StatusCake failed"
fi
