#!/bin/sh
# Usage: solve.sh
# Triggers the daily NYT Connections auto-solver and returns the result as JSON.

BASE="${SCORER_URL:-http://scorer:5000}"
curl -s -X POST "${BASE}/solve"
