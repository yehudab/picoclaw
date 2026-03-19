#!/bin/sh
# Usage: solve_status.sh
# Returns the current status of the NYT Connections solver.

BASE="${SCORER_URL:-http://scorer:5000}"
curl -s "${BASE}/solve/status"
