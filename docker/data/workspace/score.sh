#!/bin/sh
# Usage: score.sh <image_path> <user_id> <user_name> <chat_id>
BASE="${SCORER_URL:-http://scorer:5000}"
curl -s -X POST "${BASE}/score" \
  -F "image=@$1" \
  -F "user_id=$2" \
  -F "user_name=$3" \
  -F "chat_id=$4"

