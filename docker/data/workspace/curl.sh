#!/bin/sh
# Usage: curl.sh missing <chat_id>

if [ "$1" != "missing" ] || [ -z "$2" ]; then
  echo '{"error":"usage: curl.sh missing <chat_id>"}'; exit 1
fi

BASE="${SCORER_URL:-http://scorer:5000}"
curl -s "${BASE}/missing?chat_id=$2"

