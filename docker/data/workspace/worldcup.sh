#!/bin/sh
# Query the World Cup data service.
# Usage:
#   worldcup.sh today [date]            matches on a date (default: today)
#   worldcup.sh results [date]          finished matches + scores (default: yesterday)
#   worldcup.sh standings [group]       group table(s), e.g. standings A
#   worldcup.sh next <team>             a team's next scheduled match
#   worldcup.sh last <team>             a team's last result
#   worldcup.sh schedule <team>         all of a team's fixtures
#   worldcup.sh fixture <team1> <team2> prediction context (H2H + form + standings)
#   worldcup.sh predict <team1> <team2> alias for 'fixture'
#   worldcup.sh bet <team1> <team2> <score> [date]   record your predicted score (e.g. 2-1)
#   worldcup.sh review <team1> <team2>  grade your saved bet for that pairing
#   worldcup.sh review <date>           grade all saved bets for games on that date
# Team names: English name, FIFA 3-letter code (e.g. BIH, KOR), or Hebrew. QUOTE any
# name with a space or '&', e.g. "Bosnia & Herzegovina" — or use the code BIH instead.
# Dates are YYYY-MM-DD, or the keywords today / yesterday / tomorrow.
#
# The service runs at http://worldcup:5001 on the bot's Docker network. To test
# locally, point it elsewhere:  WORLDCUP_URL=http://localhost:5001 worldcup.sh ...

BASE="${WORLDCUP_URL:-http://worldcup:5001}"

# Run a curl request. On any transport failure (host unreachable, timeout, etc.)
# emit a JSON error instead of failing silently, so the bot can report it.
req() {
  out=$(curl -sS --max-time 30 "$@" 2>/tmp/worldcup_err)
  rc=$?
  if [ "$rc" -ne 0 ]; then
    err=$(cat /tmp/worldcup_err 2>/dev/null)
    echo "{\"error\":\"service_unreachable\",\"detail\":\"${err}\",\"base\":\"${BASE}\"}"
    return 1
  fi
  echo "$out"
}

case "$1" in
  today)
    if [ -n "$2" ]; then
      req -G "$BASE/today" --data-urlencode "date=$2"
    else
      req "$BASE/today"
    fi
    ;;
  results)
    if [ -n "$2" ]; then
      req -G "$BASE/results" --data-urlencode "date=$2"
    else
      req "$BASE/results"
    fi
    ;;
  standings)
    if [ -n "$2" ]; then
      req -G "$BASE/standings" --data-urlencode "group=$2"
    else
      req "$BASE/standings"
    fi
    ;;
  next|last|schedule)
    if [ -z "$2" ]; then
      echo '{"error":"team required"}'; exit 1
    fi
    req -G "$BASE/$1" --data-urlencode "team=$2"
    ;;
  fixture|predict)
    if [ -z "$2" ] || [ -z "$3" ]; then
      echo '{"error":"two teams required: fixture <team1> <team2>"}'; exit 1
    fi
    req -G "$BASE/fixture" --data-urlencode "team1=$2" --data-urlencode "team2=$3"
    ;;
  bet)
    if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
      echo '{"error":"usage: bet <team1> <team2> <score e.g. 2-1> [date]"}'; exit 1
    fi
    if [ -n "$5" ]; then
      req -G "$BASE/bets/place" --data-urlencode "team1=$2" --data-urlencode "team2=$3" \
        --data-urlencode "pred=$4" --data-urlencode "date=$5"
    else
      req -G "$BASE/bets/place" --data-urlencode "team1=$2" --data-urlencode "team2=$3" \
        --data-urlencode "pred=$4"
    fi
    ;;
  review)
    if [ -n "$3" ]; then
      req -G "$BASE/bets/review" --data-urlencode "team1=$2" --data-urlencode "team2=$3"
    elif [ -n "$2" ]; then
      req -G "$BASE/bets/review" --data-urlencode "date=$2"
    else
      echo '{"error":"usage: review <team1> <team2>  |  review <date>"}'; exit 1
    fi
    ;;
  *)
    echo "Usage: worldcup.sh today|results|standings|next|last|schedule|fixture|predict|bet|review ..."
    exit 1
    ;;
esac
