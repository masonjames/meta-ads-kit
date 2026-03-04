---
name: pixel-capi
description: "Meta Pixel + Conversions API (CAPI) setup, audit, testing, and EMQ optimization. Covers browser pixel installation, server-side CAPI implementation, deduplication, advanced matching, and Event Match Quality scoring across all major platforms."
metadata:
  openclaw:
    emoji: "🎯"
    user-invocable: true
    requires:
      tools: []
      env: []
---

# Pixel + CAPI -- Your Server-Side Signal Stack

The browser pixel alone is broken. iOS 14.5 killed 30-50% of signal. Ad blockers take another 20-30%. Cookie deprecation is finishing the job.

The fix is Conversions API (CAPI) -- server-side event sending that runs parallel to the browser pixel, shares event IDs for deduplication, and passes hashed user data that browsers can't block.

This skill audits, sets up, tests, and optimizes your Meta Pixel + CAPI stack. Target: **9.3+ EMQ on Purchase, 8.0+ on Lead**.

**Always read `references/pixel-capi-reference.md` first.** That doc is the full knowledge base. Scripts automate the work; the reference doc explains the why.

---

## Brand Memory Integration

**Reads:** `workspace/brand/stack.md` for stored pixel IDs and account IDs

| File | What it provides |
|------|-----------------|
| `workspace/brand/stack.md` | Stored pixel ID, ad account ID, platform type |

**Writes:**

| File | What it contains |
|------|-----------------|
| `workspace/brand/stack.md` | Appends pixel ID, EMQ scores, platform config |
| `workspace/brand/learnings.md` | Appends EMQ findings, platform gotchas, fixes applied |

---

## Core Concepts (Read Before Acting)

Before running any script, load `references/pixel-capi-reference.md` for:
- Why pixel + CAPI together is non-negotiable in 2026
- How deduplication works (shared event_id between browser and server)
- EMQ scoring weights (em > ph > fn+ln > fbp/fbc > ip+ua)
- Platform-specific gotchas (Next.js hydration, Shopify checkout limits, etc.)

**Key principle:** Never send PII unhashed. Scripts handle SHA-256 hashing automatically. If implementing manually, hash everything: lowercase, trim whitespace, then `sha256sum`.

---

## Workflow

### 1. Audit an Existing Pixel

Check what's configured, what's missing, infer EMQ.

```
Run: scripts/pixel-audit.sh <account_id_or_pixel_id>
```

If given an ad account ID (e.g., `act_123456`): lists all pixels, audits each.
If given a pixel ID directly: audits that pixel only.

**Output:** Scorecard with pass/fail/warning per check, estimated EMQ per event type, prioritized fix list.

**Important:** EMQ shown is an *estimate* based on configured matching fields. Actual EMQ may differ. Always verify in Events Manager > Data Sources > [Pixel] > Overview.

### 2. Set Up Pixel + CAPI for a Platform

Get platform-specific installation instructions with code snippets.

```
Run: scripts/pixel-setup.sh <platform> <pixel_id>
```

**Supported platforms:**
- `nextjs` -- App Router + Pages Router
- `shopify` -- Native + custom implementation
- `wordpress` -- WooCommerce + standard
- `webflow` -- Custom code embed approach
- `ghl` -- GoHighLevel native pixel + CAPI webhook
- `clickfunnels` -- ClickFunnels 2.0
- `custom` -- Vanilla JS / any platform

Output includes: pixel base code, standard events, advanced matching config, CAPI setup, deduplication implementation, platform-specific gotchas.

### 3. Test CAPI is Working

Send test events and verify receipt in Events Manager.

```
Run: scripts/capi-test.sh <pixel_id> [test_event_code]
```

Sends a test PageView and test Purchase. Use `test_event_code` to see events in Test Events tool without affecting real data.

After running: **Check Events Manager > Data Sources > [Pixel] > Test Events** to confirm receipt.

### 4. Check and Optimize EMQ

Get a detailed EMQ analysis with prioritized recommendations.

```
Run: scripts/emq-check.sh <pixel_id>
```

Pulls pixel config, scores each matching parameter, estimates EMQ, outputs recommendations sorted by impact (highest impact first).

EMQ targets:
- Purchase: **9.3+** (excellent), 8.0-9.2 (good), 6.0-7.9 (needs work), <6.0 (critical)
- Lead: **8.0+** (excellent), 6.5-7.9 (good), 5.0-6.4 (needs work), <5.0 (critical)

### 5. Send Server-Side Events (Manual / Custom)

Send individual CAPI events with full control over parameters.

```
Run: scripts/capi-send.sh <pixel_id> <event_name> [options]

Options:
  --email "user@example.com"
  --phone "15551234567"
  --value 109.97
  --currency USD
  --url "https://site.com/thank-you"
  --event-id "unique_dedup_id"    (auto-generated if omitted)
  --ip "203.0.113.1"
  --ua "Mozilla/5.0..."
  --fbp "fb.1.1234567890.987654321"
  --fbc "fb.1.1234567890.IwAR..."
```

PII (email, phone, names) is hashed automatically. Event ID is generated if not provided.

---

## Setup

### Get a META_TOKEN

You need a Meta access token with `ads_management` and `ads_read` permissions. Two ways:

**Option A -- System User token (recommended for CAPI):**
1. Business Manager > Business Settings > System Users
2. Create system user, assign to pixel with "Analyze" permission
3. Generate token with `ads_management` scope

**Option B -- User token:**
```bash
social auth login
# Then check: cat ~/.social-cli/config.json
```

**Store token:**
```bash
export META_TOKEN="your_token_here"
# Or add to ~/.social-cli/config.json as "meta_access_token"
```

### Get Your Pixel ID

```bash
# List all pixels for an ad account
curl -s "https://graph.facebook.com/v19.0/act_ACCOUNT_ID/adspixels?fields=name,id,last_fired_time&access_token=$META_TOKEN" | jq '.data'
```

Or run: `scripts/pixel-audit.sh act_ACCOUNT_ID`

---

## EMQ Quick Reference

| Matching Parameter | Field Key | Weight | Notes |
|-------------------|-----------|--------|-------|
| Email | `em` | Very High | Hash: lowercase, trim, sha256 |
| Phone | `ph` | Very High | Hash: digits only, country code, sha256 |
| First Name | `fn` | Medium | Hash: lowercase, trim, sha256 |
| Last Name | `ln` | Medium | Hash: lowercase, trim, sha256 |
| City | `ct` | Medium-Low | Hash: lowercase, no spaces, sha256 |
| State | `st` | Medium-Low | Hash: 2-letter code, lowercase, sha256 |
| ZIP | `zp` | Medium-Low | Hash: digits only, sha256 |
| Country | `country` | Medium-Low | Hash: 2-letter ISO, lowercase, sha256 |
| Date of Birth | `db` | Low | Hash: YYYYMMDD format, sha256 |
| Gender | `ge` | Low | Hash: m/f, sha256 |
| External ID | `external_id` | Medium | Your CRM user ID, sha256 |
| IP Address | `client_ip_address` | Low-Medium | NOT hashed, pass raw |
| User Agent | `client_user_agent` | Low-Medium | NOT hashed, pass raw |
| FBP Cookie | `fbp` | Medium | NOT hashed, read from _fbp cookie |
| FBC Cookie | `fbc` | Medium | NOT hashed, read from _fbc cookie or fbclid param |

**The 9.3+ formula:** em + ph + fn + ln + fbp + fbc + ip + ua + at least one geo field

---

## Deduplication Pattern

**Critical:** Both pixel and CAPI must fire with the same `event_id` or Meta double-counts the conversion.

```javascript
// Browser pixel
const eventId = 'evt_' + Date.now() + '_' + Math.random().toString(36).substr(2,9);

fbq('track', 'Purchase', {
  value: 109.97,
  currency: 'USD'
}, {
  eventID: eventId  // <-- pass to pixel
});

// Server-side (pass this eventId to your CAPI call)
// Scripts handle this -- just make sure your backend receives it from frontend
```

Without matching event IDs: every conversion counts twice. Ad account thinks you're getting 2x conversions you're not. Ruins optimization.

---

## Platform Quick-Start

| Platform | Pixel | CAPI | Hardest Part |
|----------|-------|------|-------------|
| Next.js | `next/script` + `react-facebook-pixel` | API route `/api/capi` | Hydration -- fire only client-side |
| Shopify | Native pixels (new UI) | Shopify CAPI native OR webhook | Checkout extensibility limits |
| WordPress | Header code or plugin | Custom webhook or plugin | WooCommerce order hooks |
| Webflow | Custom code embed | External webhook (Zapier/n8n) | No server-side access -- use Webhook |
| GHL | Native pixel field | GHL CAPI integration (native) | Attribution window settings |
| ClickFunnels 2.0 | Native pixel field | CF2 CAPI native (beta) | Limited event customization |
| Custom | Direct script tag | Server endpoint (any language) | Full control -- see reference doc |

For platform-specific code: `scripts/pixel-setup.sh <platform> <pixel_id>`

---

## Common Fixes by Symptom

**"My EMQ is 4.0"**
- Almost always: email not being passed, or fbc/fbp not captured
- Run `emq-check.sh` for specific gaps
- Add email collection at checkout/lead form and pass hashed to CAPI

**"Events are double-counting"**
- Missing event_id deduplication
- Make sure both pixel and CAPI fire with same event_id
- Check Events Manager > Diagnostics for dedup warnings

**"CAPI events not showing up"**
- Token missing `ads_management` permission
- Wrong pixel ID
- Run `capi-test.sh` with a test_event_code to debug in isolation

**"Purchase EMQ good, Lead EMQ bad"**
- Leads often have less user data (just email vs full checkout)
- Add phone field to lead forms
- Pass UTM parameters to capture fbc when fbclid present

---

## Invocation

When the user asks about:
- Meta Pixel setup, installation, base code
- Conversions API (CAPI), server-side tracking
- Event Match Quality (EMQ), matching parameters, signal quality
- iOS 14 signal loss, cookie tracking issues
- Facebook conversion tracking, event deduplication
- Pixel audit, what's missing from tracking

1. Read `references/pixel-capi-reference.md` for the full knowledge base
2. Check `workspace/brand/stack.md` for stored pixel/account IDs
3. Run the appropriate script for the task
4. Interpret EMQ scores against targets (9.3+ Purchase, 8.0+ Lead)
5. Provide prioritized fix list -- highest EMQ impact first
6. **Always remind user to verify estimated EMQ in Events Manager** (API gives config, not actual score)
7. Log findings to `workspace/brand/learnings.md`

---

## Next Up

- **`/meta-ads`** -- Campaign performance. Pair with good signal = better optimization.
- **`/ga4-report`** -- See what tracked traffic actually does on-site.
- **`/analytics-tracking`** -- Full analytics stack including GA4 event tracking.
