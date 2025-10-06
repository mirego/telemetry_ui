#!/bin/bash

# Random request generator
# Press Ctrl+C to stop

ROUTES=("/" "/foo" "/bar" "/aux" "/new")
BASE_URL="${1:-http://localhost:4000}"

echo "Starting random requests to $BASE_URL"
echo "Press Ctrl+C to stop"
echo ""

while true; do
  ROUTE=${ROUTES[$RANDOM % ${#ROUTES[@]}]}
  echo "$(date '+%H:%M:%S') - Requesting: $BASE_URL$ROUTE"
  curl -s -o /dev/null -w "Status: %{http_code}\n" "$BASE_URL$ROUTE"
  sleep $(awk -v min=0.03 -v max=0.4 'BEGIN{srand(); print min+rand()*(max-min)}')
done
