#!/usr/bin/env bash

# EMAIL=me@gmail.com
# KEY=11111111111111111111111111
# Replace with 
#     -H "X-Auth-Email: ${EMAIL}" \
#     -H "X-Auth-Key: ${KEY}" \
# for old API keys

TOKEN="${CLOUDFLARE_API_KEY}"
ZONE_ID="33aef43c9924965d6d3bc43fa99506a4"

curl -s -X GET https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?per_page=500 \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" | jq '.result[].id' |  tr -d '"' | (
  while read id; do
    curl -s -X DELETE https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$id \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json"
  done
  )
