#!/bin/sh
# Usage: score.sh <image_path> <user_id> <user_name> <chat_id>

if [ "$#" -ne 4 ]; then
  echo '{"error":"score.sh requires exactly 4 arguments: <image_path> <user_id> <user_name> <chat_id>"}'; exit 1
fi

# chat_id must look like a WhatsApp ID: digits followed by @something
case "$4" in
  *[0-9]@*.*)  ;;  # valid
  *) echo '{"error":"invalid chat_id: must be a WhatsApp ID (e.g. 1234567890@g.us)"}'; exit 1 ;;
esac

BASE="${SCORER_URL:-http://scorer:5000}"
curl -s -X POST "${BASE}/score" \
  -F "image=@$1" \
  -F "user_id=$2" \
  -F "user_name=$3" \
  -F "chat_id=$4"
