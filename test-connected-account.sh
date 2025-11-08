#!/bin/bash
# Test script for create-connected-account Edge Function
# Usage: ./test-connected-account.sh YOUR_USER_UUID YOUR_EMAIL

USER_ID=${1:-"YOUR_USER_UUID"}
EMAIL=${2:-"test@example.com"}
PROJECT_REF="mzapuczjijqjzdcujetx"  # From Config.swift
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16YXB1Y3pqaWpxanpkY3VqZXR4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE5NDkzMjcsImV4cCI6MjA3NzUyNTMyN30.r0DCKvVY5fgDOMj4dv46tOIcsHmeFzV1-M88-LC3eWA"

echo "Testing create-connected-account Edge Function..."
echo "User ID: $USER_ID"
echo "Email: $EMAIL"
echo ""

curl -X POST "https://${PROJECT_REF}.supabase.co/functions/v1/create-connected-account" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"user_id\": \"${USER_ID}\",
    \"email\": \"${EMAIL}\",
    \"country\": \"US\"
  }" \
  -v

echo ""
echo ""
echo "Check the response above for error details."

