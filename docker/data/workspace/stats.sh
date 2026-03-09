#!/bin/sh
# Usage:
#   stats.sh leaderboard
#   stats.sh summary
#   stats.sh stats <user_id>

BASE="http://scorer:5000"

case "$1" in
  leaderboard)
    curl -s "${BASE}/leaderboard?sprint=current"
    ;;
  summary)
    curl -s "${BASE}/summary?sprint=current"
    ;;
  stats)
    if [ -z "$2" ]; then
      echo '{"error":"user_id required"}'; exit 1
    fi
    curl -s "${BASE}/stats?user_id=$2&sprint=current"
    ;;
  *)
    echo "Usage: stats.sh leaderboard|summary|stats <user_id>"; exit 1
    ;;
esac

