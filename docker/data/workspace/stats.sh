#!/bin/sh
# Usage:
#   stats.sh leaderboard <chat_id>
#   stats.sh summary     <chat_id>
#   stats.sh stats <user_id> <chat_id>

BASE="${SCORER_URL:-http://scorer:5000}"

case "$1" in
  leaderboard)
    if [ -z "$2" ]; then
      echo '{"error":"chat_id required"}'; exit 1
    fi
    curl -s "${BASE}/leaderboard?sprint=current&chat_id=$2"
    ;;
  summary)
    if [ -z "$2" ]; then
      echo '{"error":"chat_id required"}'; exit 1
    fi
    curl -s "${BASE}/summary?sprint=current&chat_id=$2"
    ;;
  stats)
    if [ -z "$2" ] || [ -z "$3" ]; then
      echo '{"error":"user_id and chat_id required"}'; exit 1
    fi
    curl -s "${BASE}/stats?user_id=$2&sprint=current&chat_id=$3"
    ;;
  *)
    echo "Usage: stats.sh leaderboard|summary|stats <user_id>  <chat_id>"; exit 1
    ;;
esac

