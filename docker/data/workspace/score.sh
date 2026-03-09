#!/bin/sh
# Usage: score.sh <image_path> <user_id> <user_name>
  curl -s -X POST http://scorer:5000/score \
    -F "image=@$1" \
    -F "user_id=$2" \
    -F "user_name=$3"

