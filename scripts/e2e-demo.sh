#!/usr/bin/env bash
# OpenNoiseNet E2E Demo Script
# Verifies: device registration -> event upload -> server receipt -> dashboard visibility
#
# Usage: ./scripts/e2e-demo.sh [backend_url] [frontend_url]
#   default backend_url: http://localhost:8100

set -euo pipefail
BASE="${1:-http://localhost:8100}"
API="${BASE}/api/v1"
PASS=0
FAIL=0

green() { echo -e "\033[32m✓ $*\033[0m"; PASS=$((PASS+1)); }
red()   { echo -e "\033[31m✗ $*\033[0m"; FAIL=$((FAIL+1)); return 1; }
check() { if [ "$1" -eq 0 ]; then green "$2"; else red "$2"; fi; }

echo "=== OpenNoiseNet E2E Demo ==="
echo "Backend: $BASE"
echo

# 1. Health check
echo "--- 1. Health Check ---"
HEALTH=$(curl -sf "$BASE/health")
check $? "Health endpoint: $HEALTH"

# 2. Register user
echo "--- 2. Register Test User ---"
USER_EMAIL="e2e-$(date +%s)@noisenet.org"
REGISTER=$(curl -sf -X POST "$API/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$USER_EMAIL\",\"password\":\"testpass123\",\"full_name\":\"E2E Test\"}")
check $? "User registered: $USER_EMAIL"

TOKEN=$(echo "$REGISTER" | python3 -c "import json,sys; print(json.load(sys.stdin)['access_token'])")
[ -n "$TOKEN" ] && green "Token received" || red "Token missing"

# 3. Register device
echo "--- 3. Register Device ---"
DEVICE_ID="e2e-device-$(date +%s)"
DEVICE_KEY=$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DEVICE=$(curl -sf -X POST "$API/devices/register" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" -H "X-Device-Key: $DEVICE_KEY" \
  -d "{\"device_id\":\"$DEVICE_ID\",\"name\":\"E2E Test Device\",\"firmware_version\":\"0.1.0\",\"location_lat\":52.52,\"location_lng\":13.405}")
check $? "Device registered: $DEVICE_ID"

# 4. Submit event
echo "--- 4. Submit Noise Event ---"
CLIENT_EVENT_UUID=$(python3 -c 'import uuid; print(uuid.uuid4())')
EVENT_PAYLOAD="{\"event_uuid\":\"$CLIENT_EVENT_UUID\",\"device_id\":\"$DEVICE_ID\",\"timestamp_start\":\"$TIMESTAMP\",\"timestamp_end\":\"$TIMESTAMP\",\"leq_db\":72.3,\"lmax_db\":88.1,\"exceedance_pct\":0.55,\"rule_triggered\":\"15min_Leq_over_65dBA\",\"location_lat\":52.52,\"location_lng\":13.405}"
EVENT=$(curl -sf -X POST "$API/events/" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" -H "X-Device-Key: $DEVICE_KEY" \
  -d "$EVENT_PAYLOAD")
check $? "Event submitted"

EVENT_UUID=$(echo "$EVENT" | python3 -c "import json,sys; print(json.load(sys.stdin)['event_uuid'])")
EVENT_SERVER_ID=$(echo "$EVENT" | python3 -c "import json,sys; print(json.load(sys.stdin)['server_event_id'])")
[ -n "$EVENT_UUID" ] && green "Event UUID: $EVENT_UUID" || red "Event UUID missing"
[ "$EVENT_UUID" = "$CLIENT_EVENT_UUID" ] && green "Client event UUID preserved" || red "Client event UUID changed"

# A lost response must not create a second event when the phone retries.
RETRY=$(curl -sf -X POST "$API/events/" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" -H "X-Device-Key: $DEVICE_KEY" -d "$EVENT_PAYLOAD")
RETRY_SERVER_ID=$(echo "$RETRY" | python3 -c "import json,sys; print(json.load(sys.stdin)['server_event_id'])")
[ "$RETRY_SERVER_ID" = "$EVENT_SERVER_ID" ] && green "Retry returned the same server event" || red "Retry created a different event"

# 5. Verify event in list
echo "--- 5. Verify Event in List ---"
EVENTS=$(curl -sf -H "X-Device-Key: $DEVICE_KEY" "$API/events/")
TOTAL=$(echo "$EVENTS" | python3 -c "import json,sys; print(json.load(sys.stdin)['total'])")
[ "$TOTAL" -ge 1 ] && green "Events total: $TOTAL" || red "Events list empty"

# 6. Verify single event detail (uses server_event_id from submit response)
echo "--- 6. Verify Single Event Detail ---"
EVENT_DETAIL=$(curl -sf -H "X-Device-Key: $DEVICE_KEY" "$API/events/$EVENT_SERVER_ID")
EVENT_STATUS=$(echo "$EVENT_DETAIL" | python3 -c "import json,sys; print(json.load(sys.stdin)['status'])")
[ "$EVENT_STATUS" = "active" ] && green "Event status: $EVENT_STATUS" || red "Event status: $EVENT_STATUS"

# 7. Submit heartbeat (URL uses device_id string, not UUID)
echo "--- 7. Device Heartbeat ---"
HB=$(curl -sf -X POST "$API/devices/$DEVICE_ID/heartbeat" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" -H "X-Device-Key: $DEVICE_KEY" \
  -d "{\"device_id\":\"$DEVICE_ID\",\"timestamp\":\"$TIMESTAMP\",\"battery_level\":85,\"status\":{\"capture_active\":true,\"uptime_seconds\":3600}}")
check $? "Heartbeat submitted"

# 8. Map endpoint
echo "--- 8. Map GeoJSON ---"
MAP=$(curl -sf "$API/map/events")
TYPE=$(echo "$MAP" | python3 -c "import json,sys; print(json.load(sys.stdin)['type'])")
[ "$TYPE" = "FeatureCollection" ] && green "Map type: $TYPE" || red "Map response invalid"
echo "$MAP" | python3 -c 'import json,sys; assert not any(f["properties"].get("device_id") == sys.argv[1] for f in json.load(sys.stdin)["features"])' "$DEVICE_ID"
green "Private device is absent from the public map"
curl -sf -X PUT "$API/devices/$DEVICE_ID" -H "Content-Type: application/json" -H "X-Device-Key: $DEVICE_KEY" -d '{"is_public":true}' >/dev/null
curl -sf "$API/map/events" | python3 -c 'import json,sys; assert any(f["properties"].get("device_id") == sys.argv[1] for f in json.load(sys.stdin)["features"])' "$DEVICE_ID"
green "Explicitly public synthetic device appears on the map"

# 9. Map stats
echo "--- 9. Map Stats ---"
STATS=$(curl -sf "$API/map/stats")
EVENTS_24H=$(echo "$STATS" | python3 -c "import json,sys; print(json.load(sys.stdin)['events_24h'])")
DEVICES=$(echo "$STATS" | python3 -c "import json,sys; print(json.load(sys.stdin)['total_devices'])")
green "Stats: devices=$DEVICES, events_24h=$EVENTS_24H"

# 10. Dashboard (frontend)
echo "--- 10. Dashboard (frontend) ---"
FRONTEND_URL="${2:-$(echo "$BASE" | sed 's/8100/3100/' | sed 's|/api/v1||')}"
DASHBOARD=$(curl -sf -o /dev/null -w "%{http_code}" "${FRONTEND_URL}/")
[ "$DASHBOARD" = "200" ] && green "Dashboard HTTP $DASHBOARD" || red "Dashboard HTTP $DASHBOARD"

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -eq 0 ]; then
  echo "Status: ALL CHECKS PASSED"
  exit 0
else
  echo "Status: $FAIL CHECK(S) FAILED"
  exit 1
fi
