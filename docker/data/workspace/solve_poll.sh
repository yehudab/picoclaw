#!/bin/sh
# Wrapper called by the cron job. Checks solver status and tells the bot what to do next.

BASE="${SCORER_URL:-http://scorer:5000}"
RESULT=$(curl -s "${BASE}/solve/status")
STATUS=$(echo "$RESULT" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

echo "$RESULT"

case "$STATUS" in
  done|failed)
    echo "CRON_ACTION: stop — delete this cron job now and post the final result to the group."
    ;;
  *)
    echo "CRON_ACTION: continue — post a short 'still working' update to the group, then wait for the next cron tick."
    ;;
esac
