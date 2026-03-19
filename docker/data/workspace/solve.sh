#!/bin/sh
# Usage: solve.sh
# Starts the NYT Connections auto-solver in the background. Returns immediately.

BASE="${SCORER_URL:-http://scorer:5000}"
curl -s -X POST "${BASE}/solve"
