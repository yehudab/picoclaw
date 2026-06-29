#!/bin/sh
# Usage:
#   stats.sh leaderboard <chat_id> [sprint]
#   stats.sh summary     <chat_id> [sprint]
#   stats.sh stats       <user_id> <chat_id> [sprint]
# [sprint] is "current" (default) or "previous" (the just-finished sprint).

BASE="${SCORER_URL:-http://scorer:5000}"

case "$1" in
  leaderboard)
    if [ -z "$2" ]; then
      echo '{"error":"chat_id required"}'; exit 1
    fi
    SPRINT="${3:-current}"
    curl -s "${BASE}/leaderboard?sprint=${SPRINT}&chat_id=$2"
    ;;
  summary)
    if [ -z "$2" ]; then
      echo '{"error":"chat_id required"}'; exit 1
    fi
    SPRINT="${3:-current}"
    curl -s "${BASE}/summary?sprint=${SPRINT}&chat_id=$2"
    ;;
  stats)
    if [ -z "$2" ] || [ -z "$3" ]; then
      echo '{"error":"user_id and chat_id required"}'; exit 1
    fi
    SPRINT="${4:-current}"
    curl -s "${BASE}/stats?user_id=$2&sprint=${SPRINT}&chat_id=$3"
    ;;
  *)
    echo "Usage: stats.sh leaderboard|summary <chat_id> [sprint] | stats <user_id> <chat_id> [sprint]"; exit 1
    ;;
esac
