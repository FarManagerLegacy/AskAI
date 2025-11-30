#!/bin/sh
set -e
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36"

public_key=$(curl -s https://g4f.dev/backend-api/v2/public-key)
public_key_pem=$(mktemp -ut pem.XXXXXX)
printf '%s' "$public_key" | jq -r .public_key > "$public_key_pem"
cat <<EOF | openssl pkeyutl -encrypt -inkey "$public_key_pem" -pubin -in - -out - | base64.exe -w 0
{
  "data": "$(printf '%s' "$public_key" | jq -r .data)",
  "user": "$1",
  "timestamp": $(date +%s%3N),
  "user_agent": "$UA",
  "referrer": "https://g4f.dev/docs/ready_to_use.html",
  "provider": "Azure",
  "model": "null"
}
EOF
rm "$public_key_pem"
