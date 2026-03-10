#!/bin/sh
# Usage: correct.sh <user_id> <score> <chat_id>

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo '{"error":"usage: correct.sh <user_id> <score> <chat_id>"}'; exit 1
fi

BASE="${SCORER_URL:-http://scorer:5000}"
curl -s -X POST "${BASE}/score/correct" \
  -H "Content-Type: application/json" \
  -d "{\"user_id\":\"$1\",\"score\":$2,\"chat_id\":\"$3\"}"
