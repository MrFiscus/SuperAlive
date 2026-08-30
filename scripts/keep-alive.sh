#!/usr/bin/env bash
#
# Pings every Supabase project listed in the SUPABASE_KEEPALIVE_TARGETS secret
# so free-tier projects never hit the 7-day inactivity pause.
#
# SUPABASE_KEEPALIVE_TARGETS must be a JSON array:
#   [
#     { "name": "project-one", "url": "https://aaaaaaaa.supabase.co", "key": "SERVICE_ROLE_KEY_1" },
#     { "name": "project-two", "url": "https://bbbbbbbb.supabase.co", "key": "SERVICE_ROLE_KEY_2" }
#   ]
#
# Each request is a PostgREST read against the `keep-alive` table with a random
# filter value, so no proxy or CDN can serve it from cache.

set -euo pipefail

: "${SUPABASE_KEEPALIVE_TARGETS:?Missing SUPABASE_KEEPALIVE_TARGETS secret}"
TABLE="${KEEP_ALIVE_TABLE:-keep-alive}"

count=$(jq 'length' <<<"$SUPABASE_KEEPALIVE_TARGETS")
if [ "$count" -eq 0 ]; then
  echo "SUPABASE_KEEPALIVE_TARGETS is an empty array" >&2
  exit 1
fi

failures=0
for i in $(seq 0 $((count - 1))); do
  name=$(jq -r ".[$i].name // .[$i].url // \"target-$i\"" <<<"$SUPABASE_KEEPALIVE_TARGETS")
  url=$(jq -r ".[$i].url // empty" <<<"$SUPABASE_KEEPALIVE_TARGETS" | sed 's:/*$::')
  key=$(jq -r ".[$i].key // empty" <<<"$SUPABASE_KEEPALIVE_TARGETS")

  if [ -z "$url" ] || [ -z "$key" ]; then
    echo "✗ $name: missing \"url\" or \"key\"" >&2
    failures=$((failures + 1))
    continue
  fi

  rand=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$RANDOM-$RANDOM-$RANDOM")
  : >/tmp/keepalive_body
  status=$(curl -sS -o /tmp/keepalive_body -w '%{http_code}' \
    -H "apikey: $key" \
    -H "Authorization: Bearer $key" \
    "$url/rest/v1/$TABLE?select=id&limit=1&name=eq.$rand") || status=000

  if [ "$status" = "200" ]; then
    echo "✓ $name: ok"
  else
    echo "✗ $name: HTTP $status - $(head -c 200 /tmp/keepalive_body)" >&2
    failures=$((failures + 1))
  fi
done

if [ "$failures" -gt 0 ]; then
  echo ""
  echo "$failures target(s) failed" >&2
  exit 1
fi

echo ""
echo "All $count target(s) pinged successfully"
