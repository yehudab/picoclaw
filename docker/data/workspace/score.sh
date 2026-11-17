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
# Bound the request so a hung scorer fails fast instead of hitting the
# agent's 5-minute tool timeout with no explanation.
RESPONSE=$(curl -s --connect-timeout 10 --max-time 90 \
  -w "\nHTTP_STATUS:%{http_code}" -X POST "${BASE}/score" \
  -F "image=@$1" \
  -F "user_id=$2" \
  -F "user_name=$3" \
  -F "chat_id=$4")
CURL_EXIT=$?
if [ "$CURL_EXIT" -ne 0 ]; then
  echo "{\"status\":\"failed:scorer_unreachable (curl exit $CURL_EXIT)\"}"
  exit 1
fi
HTTP_STATUS=$(echo "$RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')
echo "$BODY"
if [ "$HTTP_STATUS" != "200" ]; then
  exit 1
fi
