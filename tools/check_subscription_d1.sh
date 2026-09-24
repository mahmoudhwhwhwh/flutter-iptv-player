#!/usr/bin/env bash
set -euo pipefail
ACCOUNT_ID="256945fedf42312ab657de0160e6ea66"
TOKEN="${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}"
base="https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}"
resp=$(curl -fsS "$base/d1/database" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json')
printf '%s' "$resp" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join(f"{x.get(\"uuid\")}\t{x.get(\"name\")}" for x in d.get("result",[])))'
