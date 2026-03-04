#!/usr/bin/env bash
# capi-test.sh -- Send test CAPI events to verify Meta Conversions API is working
#
# Usage:
#   capi-test.sh <pixel_id> [test_event_code]
#
# Sends: test PageView + test Purchase
# Events appear in Events Manager > Data Sources > [Pixel] > Test Events
# test_event_code prevents test events from affecting real data
#
# Requires: META_TOKEN env var or ~/.social-cli/config.json with meta_access_token

set -euo pipefail

API_BASE="https://graph.facebook.com/v19.0"

get_token() {
  if [[ -n "${META_TOKEN:-}" ]]; then
    echo "$META_TOKEN"
    return
  fi
  local config="$HOME/.social-cli/config.json"
  if [[ -f "$config" ]]; then
    local tok
    tok=$(jq -r '.meta_access_token // .access_token // empty' "$config" 2>/dev/null || true)
    [[ -n "$tok" ]] && echo "$tok" && return
  fi
  echo "ERROR: META_TOKEN not set and not found in ~/.social-cli/config.json" >&2
  echo "Set it: export META_TOKEN=your_token" >&2
  exit 1
}

if [[ $# -lt 1 ]]; then
  echo "Usage: capi-test.sh <pixel_id> [test_event_code]" >&2
  exit 1
fi

PIXEL_ID="$1"
TEST_CODE="${2:-TEST$(date +%s | tail -c 6)}"
TOKEN=$(get_token)

NOW=$(date +%s)
RAND=$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8 2>/dev/null || echo "$(date +%s%N | tail -c 8)")

# Test user data (fake, but properly hashed)
# Using test values: test@example.com, 15555550100
TEST_EMAIL_HASH="$(echo -n 'test@example.com' | sha256sum | cut -d' ' -f1)"
TEST_PHONE_HASH="$(echo -n '15555550100' | sha256sum | cut -d' ' -f1)"

echo ""
echo "========================================"
echo "CAPI TEST"
echo "Pixel ID: $PIXEL_ID"
echo "Test Event Code: $TEST_CODE"
echo "========================================"
echo ""
echo "Sending test events with fake user data (test@example.com)"
echo "These events will appear in Events Manager > Test Events only."
echo ""

# ---- Test PageView ----
PAGEVIEW_EVENT_ID="test_pv_${RAND}_${NOW}"

PAGEVIEW_PAYLOAD=$(jq -n \
  --arg event_id "$PAGEVIEW_EVENT_ID" \
  --arg event_time "$NOW" \
  --arg email_hash "$TEST_EMAIL_HASH" \
  --arg test_code "$TEST_CODE" \
  '{
    data: [{
      event_name: "PageView",
      event_time: ($event_time | tonumber),
      event_id: $event_id,
      event_source_url: "https://test.example.com/",
      action_source: "website",
      user_data: {
        em: $email_hash,
        client_ip_address: "203.0.113.1",
        client_user_agent: "Mozilla/5.0 (Test) AppleWebKit/537.36 CAPI-Test",
        fbp: "fb.1.1234567890.987654321",
        fbc: "fb.1.1234567890.testfbclid123"
      }
    }],
    test_event_code: $test_code
  }')

echo "Sending test PageView..."
PV_RESPONSE=$(curl -sf -X POST \
  "${API_BASE}/${PIXEL_ID}/events?access_token=${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$PAGEVIEW_PAYLOAD" 2>&1 || echo '{"error":"curl_failed"}')

PV_EVENTS_RECEIVED=$(echo "$PV_RESPONSE" | jq -r '.events_received // 0' 2>/dev/null || echo 0)
PV_ERROR=$(echo "$PV_RESPONSE" | jq -r '.error.message // empty' 2>/dev/null || true)

if [[ "$PV_EVENTS_RECEIVED" -gt 0 ]]; then
  echo "  [PASS] PageView received -- events_received: $PV_EVENTS_RECEIVED"
elif [[ -n "$PV_ERROR" ]]; then
  echo "  [FAIL] PageView error: $PV_ERROR"
  echo "         Full response: $PV_RESPONSE"
else
  echo "  [WARN] Unexpected response: $PV_RESPONSE"
fi

# ---- Test Purchase ----
PURCHASE_EVENT_ID="test_purchase_${RAND}_${NOW}"
PURCHASE_TIME=$((NOW - 30))  # 30 seconds ago

PURCHASE_PAYLOAD=$(jq -n \
  --arg event_id "$PURCHASE_EVENT_ID" \
  --arg event_time "$PURCHASE_TIME" \
  --arg email_hash "$TEST_EMAIL_HASH" \
  --arg phone_hash "$TEST_PHONE_HASH" \
  --arg test_code "$TEST_CODE" \
  '{
    data: [{
      event_name: "Purchase",
      event_time: ($event_time | tonumber),
      event_id: $event_id,
      event_source_url: "https://test.example.com/thank-you",
      action_source: "website",
      user_data: {
        em: $email_hash,
        ph: $phone_hash,
        fn: "2b4a247aa65f27c6a3d80f141e3bf6adb1e7c8b21b5c66cac7c52c7dc09baf39",
        ln: "f9c1e9c9c7e1f0b3a4e7a6a6d7f3d0d7af1e4c28c2e6a2bab51df7d5c2e3b62",
        client_ip_address: "203.0.113.1",
        client_user_agent: "Mozilla/5.0 (Test) AppleWebKit/537.36 CAPI-Test",
        fbp: "fb.1.1234567890.987654321",
        fbc: "fb.1.1234567890.testfbclid123",
        ct: "a172b1ef29a9d4a68bf9b3c6e84cdaaac1b55bf34d8f4e23f4bc62ba8e25c2c7",
        st: "1dbc9fde76d3adc9a6b4c5b7e6e2e19c59e0a02b8c6a0c4eb7b5c5e1e0f2e15",
        zp: "b7e2c2e3a2e5c4e2d2a4b7f4d4e1e7c4b5e6d2e1e1e8c4d5e3e7c4b4c6e4d5e",
        country: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      },
      custom_data: {
        currency: "USD",
        value: 1.00,
        contents: [{"id": "test_sku", "quantity": 1}],
        num_items: 1
      }
    }],
    test_event_code: $test_code
  }')

echo ""
echo "Sending test Purchase..."
PU_RESPONSE=$(curl -sf -X POST \
  "${API_BASE}/${PIXEL_ID}/events?access_token=${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$PURCHASE_PAYLOAD" 2>&1 || echo '{"error":"curl_failed"}')

PU_EVENTS_RECEIVED=$(echo "$PU_RESPONSE" | jq -r '.events_received // 0' 2>/dev/null || echo 0)
PU_ERROR=$(echo "$PU_RESPONSE" | jq -r '.error.message // empty' 2>/dev/null || true)
PU_FBTRACE=$(echo "$PU_RESPONSE" | jq -r '.fbtrace_id // empty' 2>/dev/null || true)

if [[ "$PU_EVENTS_RECEIVED" -gt 0 ]]; then
  echo "  [PASS] Purchase received -- events_received: $PU_EVENTS_RECEIVED"
  [[ -n "$PU_FBTRACE" ]] && echo "  fbtrace_id: $PU_FBTRACE"
elif [[ -n "$PU_ERROR" ]]; then
  echo "  [FAIL] Purchase error: $PU_ERROR"
  echo "         Full response: $PU_RESPONSE"

  # Common error hints
  if echo "$PU_ERROR" | grep -qi "permission"; then
    echo ""
    echo "  HINT: Token may be missing 'ads_management' permission."
    echo "  Generate a new System User token with ads_management scope."
  fi
  if echo "$PU_ERROR" | grep -qi "token"; then
    echo ""
    echo "  HINT: Check your META_TOKEN is valid and not expired."
    echo "  Business Manager > System Users > Generate New Token"
  fi
  if echo "$PU_ERROR" | grep -qi "pixel"; then
    echo ""
    echo "  HINT: Verify pixel ID $PIXEL_ID is correct."
    echo "  Run: pixel-audit.sh act_YOUR_ACCOUNT_ID"
  fi
else
  echo "  [WARN] Unexpected response: $PU_RESPONSE"
fi

# ---- Results ----
echo ""
echo "========================================"
echo "RESULTS"
echo "========================================"

if [[ "$PV_EVENTS_RECEIVED" -gt 0 && "$PU_EVENTS_RECEIVED" -gt 0 ]]; then
  echo "  SUCCESS -- CAPI is working!"
  echo ""
  echo "  Verify in Events Manager:"
  echo "  1. Go to: https://business.facebook.com/events_manager2"
  echo "  2. Data Sources > Select your pixel"
  echo "  3. Click 'Test Events' tab"
  echo "  4. Enter test event code: $TEST_CODE"
  echo "  5. You should see PageView and Purchase events"
  echo ""
  echo "  Events appear within 1-2 minutes."
elif [[ "$PV_EVENTS_RECEIVED" -gt 0 || "$PU_EVENTS_RECEIVED" -gt 0 ]]; then
  echo "  PARTIAL -- Some events sent, some failed. Check errors above."
else
  echo "  FAILED -- No events received. Check errors above."
  echo ""
  echo "  Common fixes:"
  echo "  1. Verify META_TOKEN has 'ads_management' permission"
  echo "  2. Verify pixel ID is correct: $PIXEL_ID"
  echo "  3. Check token is not expired"
  echo "  4. Verify pixel is associated with your Business Manager"
fi

echo ""
echo "Test Event Code used: $TEST_CODE"
echo "PageView Event ID: $PAGEVIEW_EVENT_ID"
echo "Purchase Event ID: $PURCHASE_EVENT_ID"
echo "========================================"
