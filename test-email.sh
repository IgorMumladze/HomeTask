#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-http://localhost:5001}"
TOKEN="${TOKEN:-test_secret_token_12345}"

timestamp=$(date +%s)

echo "1) Health check"
curl -s "$API_URL/health" | jq .

echo
echo "2) Send email"
response=$(curl -s -X POST "$API_URL/send-email" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "email_subject": "Test Email",
      "email_sender": "Local Tester",
      "email_timestream": "'$timestamp'",
      "email_content": "Hello from test script"
    },
    "token": "'$TOKEN'"
  }')
echo "$response" | jq .

msg_id=$(echo "$response" | jq -r '.message_id // empty')

echo
echo "3) Worker logs (tail)"
docker compose logs --tail=20 email-worker

if [[ -n "$msg_id" ]]; then
  echo
  echo "4) (Optional) check S3 for message_id $msg_id"
  echo "   aws s3 ls s3://igor-home-task-prod-app-data-371670420772-west1/emails/ --recursive --region us-west-1 | grep \"$msg_id\""
fi

echo
echo "Done."

