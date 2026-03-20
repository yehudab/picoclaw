#!/bin/sh
# Called by the daily sprint-end cron job.
# Checks whether a sprint just ended and outputs a SPRINT_ACTION signal.
#
# Usage: sprint_end_check.sh <chat_id>

if [ -z "$1" ]; then
  echo '{"error":"chat_id required"}'; exit 1
fi

BASE="${SCORER_URL:-http://scorer:5000}"
RESULT=$(curl -s "${BASE}/sprint/end_report?chat_id=$1")
SHOULD_POST=$(echo "$RESULT" | grep -o '"should_post":[^,}]*' | cut -d: -f2 | tr -d ' ')

echo "$RESULT"

if [ "$SHOULD_POST" = "true" ]; then
  echo "SPRINT_ACTION: post"
else
  echo "SPRINT_ACTION: skip"
fi
