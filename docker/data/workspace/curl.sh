#!/bin/sh
# Usage: curl.sh <path>
# Example: curl.sh missing

if [ -z "$1" ]; then
  echo '{"error":"path required"}'; exit 1
fi

curl -s "http://scorer:5000/$1"

