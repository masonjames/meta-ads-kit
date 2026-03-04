# Meta Pixel + CAPI Reference

Complete knowledge base for Meta Pixel and Conversions API implementation, optimization, and troubleshooting.

---

## 1. Overview -- Why Pixel + CAPI Together

The Meta Pixel alone is broken in 2026. Here is what is killing your signal:

**iOS 14.5+ (2021 -- ongoing)**
Apple's App Tracking Transparency (ATT) requires opt-in for tracking. Opt-in rates are 15-30%. This means 70-85% of iOS users who visit your site generate zero pixel signal. On mobile-heavy traffic (ecommerce, DTC, consumer apps), this is catastrophic.

**Ad blockers**
uBlock Origin, Privacy Badger, Brave browser, and system-level blockers (NextDNS, Pi-hole) block pixel requests at the DNS or network layer. Estimated 20-40% of desktop users have some form of ad blocker. The Meta pixel domain `connect.facebook.net` is on virtually every blocklist.

**Third-party cookie deprecation**
Safari has blocked third-party cookies since 2020. Firefox since 2019. Chrome's Privacy Sandbox is shifting tracking fundamentally. Without third-party cookies, cross-site tracking breaks, and Meta's ability to match conversions to ad clicks degrades.

**The result:** If you rely on the browser pixel alone, you are likely reporting 40-60% of actual conversions. Your ROAS looks worse than it is. Your campaigns optimize on incomplete data. Your cost per result is artificially inflated because Meta's algorithm can't see the full picture.

**The fix: Conversions API (CAPI)**

CAPI sends events from your server directly to Meta's servers. Server-to-server. No browser. No ad blockers. No iOS restrictions. No cookie dependency. Your server has the data; you send it.

Run pixel and CAPI together:
- Pixel fires from the browser (fast, real-time, captures fbp/fbc cookies)
- CAPI fires from your server (reliable, blocked-traffic recovery, hashed PII)
- Both fire with the same event_id -- Meta deduplicates automatically
- Net result: 85-100% event capture vs. 40-60% with pixel alone

This is not optional anymore. It is table stakes.

---

## 2. Architecture

```
User Browser                 Your Server              Meta Servers
     |                            |                         |
     |--[1] Page loads ---------->|                         |
     |<-[2] HTML + pixel code ----|                         |
     |                            |                         |
     |--[3] fbq('init') --------->| (client-side only)      |
     |--[4] fbq('track',          |                         |
     |       'Purchase', data,    |                         |
     |       {eventID: 'evt_123'})|                         |
     |          \                 |                         |
     |           \-[5] Pixel hit ->                         |
     |                 -> connect.facebook.net/tr ---------->|
     |                            |                         |
     |--[6] POST /api/checkout -->|                         |
     |    { email, cart, fbp,     |                         |
     |      fbc, eventId='evt_123'|                         |
     |    }                       |                         |
     |                            |--[7] CAPI POST -------->|
     |                            |  graph.facebook.com     |
     |                            |  /PIXEL_ID/events       |
     |                            |  { event_name: Purchase |
     |                            |    event_id: 'evt_123'  |
     |                            |    user_data: {hashed}  |
     |                            |  }                      |
     |                            |                         |
     |                            |         [8] Meta sees both events
     |                            |             with same event_id
     |                            |             = counts as ONE conversion
```

Key design decisions:
- event_id is generated client-side and passed to the server
- Server receives fbp and fbc cookies from the client (browser can read them, server cannot without cookies being passed explicitly)
- Server hashes all PII before sending
- Meta's deduplication window is 48 hours -- if events arrive within 48h with matching event_name + event_id, they count once

---

## 3. Pixel Setup Checklist

### Base code installation

Place in `<head>` on every page. The pixel must load before any events fire.

```html
<script>
  !function(f,b,e,v,n,t,s){if(f.fbq)return;n=f.fbq=function(){n.callMethod?
  n.callMethod.apply(n,arguments):n.queue.push(arguments)};
  if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
  n.queue=[];t=b.createElement(e);t.async=!0;
  t.src=v;s=b.getElementsByTagName(e)[0];
  s.parentNode.insertBefore(t,s)}(window, document,'script',
  'https://connect.facebook.net/en_US/fbevents.js');

  fbq('init', 'YOUR_PIXEL_ID');  // Advanced matching object goes here as second arg
  fbq('track', 'PageView');
</script>
<noscript>
  <img height="1" width="1" style="display:none"
    src="https://www.facebook.com/tr?id=YOUR_PIXEL_ID&ev=PageView&noscript=1"/>
</noscript>
```

### Domain verification

Required for conversions tracking. Without it, CAPI events may be rejected.
1. Business Manager > Brand Safety > Domains > Add Domain
2. Choose DNS verification (add TXT record) or HTML file method
3. Verify the domain where your events fire

### Standard events checklist

| Event | When to fire | Required fields |
|-------|-------------|-----------------|
| PageView | Every page load | (none) |
| ViewContent | Product/content page | content_ids, content_type, value, currency |
| AddToCart | Add to cart action | content_ids, value, currency |
| InitiateCheckout | Checkout page load | value, currency, num_items |
| Purchase | Order confirmation | value, currency (required for optimization) |
| Lead | Form submission | (none required, but pass as much as possible) |
| CompleteRegistration | Account creation | (none required) |

### Custom events

For events not covered by standard: use `fbq('trackCustom', 'EventName', data)`.
Custom events cannot be used for conversion optimization directly but can be used for retargeting audiences.

---

## 4. Advanced Matching

Advanced matching tells Meta who the person is at page load, improving attribution even when cookies are blocked.

### All matching parameters

| Field | Key | Format before hashing | Hash? |
|-------|-----|----------------------|-------|
| Email | em | lowercase, trimmed | YES (sha256) |
| Phone | ph | digits only, country code prefix (e.g., 15551234567) | YES (sha256) |
| First name | fn | lowercase, trimmed | YES (sha256) |
| Last name | ln | lowercase, trimmed | YES (sha256) |
| Date of birth | db | YYYYMMDD | YES (sha256) |
| Gender | ge | m or f | YES (sha256) |
| City | ct | lowercase, no diacritics | YES (sha256) |
| State/Province | st | 2-letter lowercase (e.g., ny, ca) | YES (sha256) |
| ZIP/Postal | zp | digits only for US; format varies by country | YES (sha256) |
| Country | country | 2-letter ISO lowercase (e.g., us, gb) | YES (sha256) |
| External ID | external_id | your CRM/user ID | YES (sha256) |
| IP Address | client_ip_address | raw IP string | NO |
| User Agent | client_user_agent | raw UA string | NO |
| FBP cookie | fbp | raw cookie value | NO |
| FBC cookie | fbc | raw cookie value | NO |

### SHA-256 hashing

```bash
# Email
echo -n "user@example.com" | sha256sum | cut -d' ' -f1

# Phone (digits only, country code)
echo -n "15551234567" | sha256sum | cut -d' ' -f1

# Name (lowercase, trim)
echo -n "john" | sha256sum | cut -d' ' -f1

# Python equivalent
import hashlib
hashlib.sha256("user@example.com".strip().lower().encode()).hexdigest()
```

### Automatic vs manual matching

**Automatic matching:** Meta's pixel JavaScript reads form fields on the page and hashes them automatically. Enabled in Events Manager > Pixel Settings. Catches email/phone/name fields without code changes.

**Manual matching:** You pass the hashed values explicitly in the `fbq('init', pixelId, { em: hash })` call. More reliable -- doesn't depend on Meta reading your form structure correctly.

Best practice: enable automatic matching AND implement manual matching for critical pages (checkout, lead form submission). Double coverage beats either alone.

---

## 5. CAPI Implementation

### Direct integration (recommended for control)

Your server calls the Meta Graph API directly.

**Endpoint:**
```
POST https://graph.facebook.com/v19.0/{pixel_id}/events?access_token={token}
```

**Required fields per event:**
- `event_name` -- Standard event name (Purchase, Lead, etc.)
- `event_time` -- Unix timestamp (integer)
- `action_source` -- "website" for web events (also: "email", "app", "phone_call", "chat", "physical_store", "system_generated", "other")
- `user_data` -- At least one identifier (em, ph, fbp, fbc, or client_ip_address + client_user_agent)

**Strongly recommended:**
- `event_id` -- For deduplication with browser pixel
- `event_source_url` -- URL where the event happened

### Access token

Use a System User token for production. System Users don't expire like regular user tokens.

1. Business Manager > Business Settings > System Users
2. Create system user
3. Assign to the pixel with "Analyze" permission
4. Generate token > select scopes: `ads_management`, `ads_read`
5. Token does not expire (unless you revoke it or revoke app access)

Alternatively, use `social auth login` via social-cli to get a user token (expires in 60 days typically).

### Partner integrations

For platforms with native CAPI support, use their built-in integration:
- **Shopify:** Meta app > "Maximum" data sharing
- **WooCommerce:** Facebook for WooCommerce plugin > CAPI settings
- **GHL:** Native CAPI integration in Integrations > Meta
- **Klaviyo:** Native CAPI for email-attributed conversions
- **GTM Server-Side:** Route pixel events through server GTM container

These are convenient but offer less control. Run the `capi-test.sh` script to verify they're actually sending.

---

## 6. CAPI Payload Reference

### Purchase

```json
{
  "data": [{
    "event_name": "Purchase",
    "event_time": 1700000000,
    "event_id": "purchase_ORD123_1700000000",
    "event_source_url": "https://yourstore.com/thank-you",
    "action_source": "website",
    "user_data": {
      "em": "sha256_hashed_email",
      "ph": "sha256_hashed_phone",
      "fn": "sha256_hashed_first_name",
      "ln": "sha256_hashed_last_name",
      "ct": "sha256_hashed_city",
      "st": "sha256_hashed_state",
      "zp": "sha256_hashed_zip",
      "country": "sha256_hashed_country",
      "client_ip_address": "203.0.113.1",
      "client_user_agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)...",
      "fbp": "fb.1.1234567890.987654321",
      "fbc": "fb.1.1234567890.IwAR2abc123..."
    },
    "custom_data": {
      "currency": "USD",
      "value": 109.97,
      "order_id": "ORD123",
      "contents": [
        {"id": "SKU_001", "quantity": 2, "item_price": 39.99},
        {"id": "SKU_002", "quantity": 1, "item_price": 29.99}
      ],
      "num_items": 3,
      "content_type": "product"
    }
  }]
}
```

### Lead

```json
{
  "data": [{
    "event_name": "Lead",
    "event_time": 1700000000,
    "event_id": "lead_FORM_1700000000_abc123",
    "event_source_url": "https://yoursite.com/get-quote",
    "action_source": "website",
    "user_data": {
      "em": "sha256_hashed_email",
      "ph": "sha256_hashed_phone",
      "fn": "sha256_hashed_first_name",
      "ln": "sha256_hashed_last_name",
      "client_ip_address": "203.0.113.1",
      "client_user_agent": "Mozilla/5.0...",
      "fbp": "fb.1.1234567890.987654321",
      "fbc": "fb.1.1234567890.IwAR..."
    },
    "custom_data": {
      "lead_id": "LEAD_12345",
      "value": 50.00,
      "currency": "USD"
    }
  }]
}
```

### ViewContent

```json
{
  "data": [{
    "event_name": "ViewContent",
    "event_time": 1700000000,
    "event_id": "vc_SKU001_1700000000",
    "event_source_url": "https://yourstore.com/products/widget",
    "action_source": "website",
    "user_data": {
      "client_ip_address": "203.0.113.1",
      "client_user_agent": "Mozilla/5.0...",
      "fbp": "fb.1.1234567890.987654321"
    },
    "custom_data": {
      "content_ids": ["SKU_001"],
      "content_type": "product",
      "value": 39.99,
      "currency": "USD",
      "content_name": "Blue Widget Pro"
    }
  }]
}
```

### AddToCart

```json
{
  "data": [{
    "event_name": "AddToCart",
    "event_time": 1700000000,
    "event_id": "atc_SKU001_1700000000_abc",
    "event_source_url": "https://yourstore.com/cart",
    "action_source": "website",
    "user_data": {
      "em": "sha256_hashed_email",
      "client_ip_address": "203.0.113.1",
      "client_user_agent": "Mozilla/5.0...",
      "fbp": "fb.1.1234567890.987654321"
    },
    "custom_data": {
      "content_ids": ["SKU_001"],
      "content_type": "product",
      "value": 39.99,
      "currency": "USD"
    }
  }]
}
```

### CompleteRegistration

```json
{
  "data": [{
    "event_name": "CompleteRegistration",
    "event_time": 1700000000,
    "event_id": "reg_USER123_1700000000",
    "event_source_url": "https://yourapp.com/welcome",
    "action_source": "website",
    "user_data": {
      "em": "sha256_hashed_email",
      "fn": "sha256_hashed_first_name",
      "ln": "sha256_hashed_last_name",
      "external_id": "sha256_hashed_user_id",
      "client_ip_address": "203.0.113.1",
      "client_user_agent": "Mozilla/5.0...",
      "fbp": "fb.1.1234567890.987654321"
    },
    "custom_data": {
      "status": "registered",
      "plan": "free_trial"
    }
  }]
}
```

---

## 7. Event Match Quality (EMQ)

### What it is

EMQ is a 0-10 score Meta assigns to each event type based on how well the user data you send matches Meta's user database. Higher score = Meta can match more of your events to Facebook/Instagram users = better attribution = better optimization.

You can see your actual EMQ in: Events Manager > Data Sources > [Pixel] > Overview

### How it's calculated

Meta does not publish the exact algorithm. Based on published guidance and testing:

| Parameter | Relative Weight | Notes |
|-----------|----------------|-------|
| Email (em) | Very High (approx 25-30%) | Single best identifier |
| Phone (ph) | High (approx 20-25%) | Strong secondary identifier |
| First + Last Name | Medium (approx 15% combined) | Must have both for best effect |
| FBP cookie | Medium (approx 10-12%) | Strong for browser-based attribution |
| FBC cookie | Medium (approx 8-10%) | Especially valuable for click-attributed |
| IP + User Agent | Low-Medium (approx 8-10% combined) | Required baseline |
| Geographic fields | Low (approx 5-8% combined) | City, state, zip, country |
| External ID | Medium (approx 5%) | Helps cross-device |
| Date of Birth | Low (approx 2-3%) | Rarely available |
| Gender | Low (approx 2-3%) | Rarely available |

### EMQ target thresholds

| Score | Assessment |
|-------|-----------|
| 9.3 - 10.0 | Excellent -- optimal signal for Purchase |
| 8.0 - 9.2 | Good -- solid Lead-level signal |
| 6.0 - 7.9 | Needs improvement -- measurable performance impact |
| 4.0 - 5.9 | Poor -- campaigns flying partially blind |
| 0 - 3.9 | Critical -- immediate action required |

### How to check your actual EMQ

1. Go to Meta Business Manager
2. Events Manager > Data Sources
3. Select your pixel
4. Overview tab
5. Look for "Event Match Quality" section -- shows per-event-type score
6. Also shows which parameters are matching and at what rate

---

## 8. Deduplication

### Why it matters

When both pixel and CAPI are running, they both fire for the same event. Without deduplication, Meta counts each as a separate conversion. A $100 purchase becomes two $100 purchases in your reporting. Your ROAS doubles artificially. Your algorithm optimizes toward people who "buy twice" -- which isn't a real signal. Campaigns get confused.

### How deduplication works

Meta matches events by `event_name` + `event_id`. If two events arrive within 48 hours with the same event_name and event_id, Meta counts them as one.

### Implementation pattern

**Step 1: Generate event_id client-side before firing either event**

```javascript
// Generate a unique, stable ID for this specific event occurrence
const eventId = [
  'evt',
  Date.now(),
  Math.random().toString(36).substr(2, 9)
].join('_');
// Example: "evt_1700000000000_a3k9xb2m1"
```

**Step 2: Pass to browser pixel**

```javascript
fbq('track', 'Purchase', {
  value: 109.97,
  currency: 'USD'
}, {
  eventID: eventId  // Note: 'eventID' (camelCase) in pixel
});
```

**Step 3: Pass to your server**

```javascript
// Include in your API call to your own backend
fetch('/api/checkout/complete', {
  method: 'POST',
  body: JSON.stringify({
    orderId: order.id,
    eventId: eventId,  // <-- same ID
    fbp: getCookie('_fbp'),
    fbc: getCookie('_fbc'),
    // ...
  })
});
```

**Step 4: Include in CAPI payload**

```json
{
  "data": [{
    "event_name": "Purchase",
    "event_id": "evt_1700000000000_a3k9xb2m1",
    // ...
  }]
}
```

### What makes a good event_id

- Unique per event occurrence (not per user or per order alone -- per firing)
- Consistent between pixel and CAPI for the same event
- If a user refreshes the thank-you page, it should fire a NEW event_id (or re-use the order-based one if idempotency is desired)
- Order-based IDs (purchase_{orderId}_{timestamp}) work well for Purchase -- naturally unique and idempotent

---

## 9. FBP and FBC Cookies

### FBP (_fbp cookie)

FBP is the Facebook Browser ID. Meta's pixel sets this cookie automatically when it loads. It identifies the browser instance persistently.

**Format:** `fb.1.{timestamp}.{random_number}`
**Example:** `fb.1.1596484480.556186797`

**Reading FBP in JavaScript:**
```javascript
function getFbp() {
  const match = document.cookie.match(/(?:^|;\s*)_fbp=(fb\.[^;]+)/);
  return match ? match[1] : null;
}
```

**Why it matters:** FBP helps Meta attribute conversions to browsers even when cookies are cleared. It's a persistent 90-day cookie. Always pass it if present.

### FBC (_fbc cookie)

FBC is the Facebook Click ID. It's created when a user clicks a Meta ad with an fbclid parameter in the URL. Meta's pixel creates the _fbc cookie from the fbclid URL param.

**Format:** `fb.1.{timestamp}.{fbclid_value}`
**Example:** `fb.1.1596484480.IwAR3plnW4OHoRNxBT38gEOsz3-HWPbMNVUm...`

**Reading FBC in JavaScript:**
```javascript
function getFbc() {
  // First: check cookie (set by pixel from previous fbclid)
  const cookieMatch = document.cookie.match(/(?:^|;\s*)_fbc=(fb\.[^;]+)/);
  if (cookieMatch) return cookieMatch[1];

  // Second: build from current URL's fbclid param
  const params = new URLSearchParams(window.location.search);
  const fbclid = params.get('fbclid');
  if (fbclid) {
    return `fb.1.${Date.now()}.${fbclid}`;
  }

  return null;
}
```

**Why it matters:** FBC directly ties a server-side event to a specific ad click. This is the most powerful attribution signal for paid campaigns. If a user clicked your ad and then converted, FBC proves the connection. Pass it in every CAPI event when available.

### Passing to server

On every form submission or conversion event, send fbp and fbc to your server:

```javascript
const payload = {
  // ...order data...
  fbp: getFbp(),
  fbc: getFbc(),
};
```

Your server passes these raw (not hashed) in the CAPI user_data:

```json
"user_data": {
  "fbp": "fb.1.1596484480.556186797",
  "fbc": "fb.1.1596484480.IwAR3plnW4OHoRNx..."
}
```

---

## 10. Pixel Conditioning

### New pixel warm-up

A new pixel needs to collect data before Meta's algorithm can optimize against it effectively. This is the "learning phase."

**What happens during learning:**
- Meta is building a model of who converts for you
- Delivery is less efficient -- CPA and CPM are higher
- Results are volatile -- ignore day-to-day swings
- Campaigns show "Learning" status in Ads Manager

**Requirements to exit learning:**
- ~50 optimization events per ad set per week
- For Purchase optimization: 50 purchases per ad set per 7 days
- For Lead: 50 leads per ad set per 7 days

**How to speed up learning:**
1. Start with a broader event (Add to Cart, Initiate Checkout) if Purchase volume is low
2. Consolidate ad sets -- fewer ad sets with higher budget each
3. Avoid editing campaigns during learning (resets the counter)
4. Use Advantage+ Shopping Campaigns which handle this automatically

### Pixel history matters

Older pixels with conversion history perform better than new ones. When launching a new site/product:
- Use an existing pixel if you have one with relevant purchase history
- If you must use a new pixel, start campaigns with awareness/traffic objectives first to build signal
- Do not create a new pixel just because you changed your site design

---

## 11. EMQ Optimization Playbook

### Starting at 0-4.0 (Critical)

You have almost no signal. Campaigns cannot optimize.

**Immediate actions:**
1. Verify pixel is firing at all (install Pixel Helper Chrome extension, check Events Manager)
2. Set up CAPI even in minimal form (just IP + UA + fbp)
3. Enable automatic advanced matching in pixel settings
4. Add email collection to your conversion pages if not present

**Expected EMQ after:** 4.0-6.0

### Moving from 4.0-6.0 to 7.0-8.0

You have basic signal but missing key identifiers.

**Actions:**
1. Add email to CAPI payload (biggest single gain)
2. Add phone to lead/checkout forms and pass to CAPI
3. Capture and pass FBP + FBC cookies in every CAPI call
4. Pass client_ip_address and client_user_agent in every CAPI call
5. Verify deduplication is working (check Events Manager Diagnostics for "deduplicated" events)

**Expected EMQ after:** 7.5-8.5

### Moving from 8.0-9.0 to 9.3+

You have strong signal. Final optimizations.

**Actions:**
1. Add first + last name to CAPI (both -- combined effect is stronger than either alone)
2. Add geographic fields (city, state, zip, country) from billing/shipping address
3. Pass external_id (your CRM user ID, hashed) -- helps cross-device
4. Enable first-party cookies on the pixel
5. Verify date of birth or gender if you collect them and GDPR/CCPA allows
6. Ensure you're passing fbc specifically (not just fbp) for ad-click attribution

**Expected EMQ after:** 9.0-9.8

### Common EMQ fixes by root cause

**"My EMQ is 4.0 despite having email enabled"**
- The field is configured but not actually present in most events
- Check what percentage of your users provide email (anonymous sessions won't have it)
- This is normal for ViewContent/PageView -- focus EMQ optimization on Lead/Purchase where you have user data

**"EMQ looks good but ROAS is still bad"**
- EMQ and ROAS are related but not the same thing
- Check if your conversion window matches your sales cycle (a 7-day attribution window may miss slow converters)
- Verify conversion events are firing at the right moment (not too early in checkout)
- Check if you have duplicate events inflating reported conversions

**"FBP is present but EMQ is still low"**
- FBP alone without email/phone is only worth ~1 point of EMQ
- FBP is a secondary signal, not a primary identifier
- Focus on getting email in first

---

## 12. Platform-Specific Guides

### Next.js (App Router)

**Pixel installation:**
Use `next/script` with `strategy="afterInteractive"` -- this ensures the script loads after Next.js hydration completes.

```tsx
// app/layout.tsx
import Script from 'next/script'

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        {children}
        <Script id="fb-pixel" strategy="afterInteractive">
          {`
            !function(f,b,e,v,n,t,s){...}(window, document,'script',
            'https://connect.facebook.net/en_US/fbevents.js');
            fbq('init', 'PIXEL_ID');
            fbq('track', 'PageView');
          `}
        </Script>
      </body>
    </html>
  )
}
```

**Route change tracking (App Router):**
In App Router, page transitions don't trigger traditional page loads. Use a client component that tracks route changes:

```tsx
'use client'
import { usePathname, useSearchParams } from 'next/navigation'
import { useEffect } from 'react'

export function PixelPageView() {
  const pathname = usePathname()
  const searchParams = useSearchParams()

  useEffect(() => {
    window.fbq?.('track', 'PageView')
  }, [pathname, searchParams])

  return null
}
```

**CAPI via API route:**
Create `app/api/capi/route.ts` (see pixel-setup.sh nextjs output for full implementation).

**Common gotchas:**
- Never call `fbq()` in server components -- it's a browser API
- Wrap `fbq` calls in `typeof window !== 'undefined'` checks if needed
- The `eventID` param goes in the third argument of `fbq('track', name, data, options)` -- not the data object

### Next.js (Pages Router)

**Pixel installation via _document.tsx or _app.tsx:**

```tsx
// pages/_app.tsx
import { useEffect } from 'react'
import { useRouter } from 'next/router'
import Script from 'next/script'

export default function App({ Component, pageProps }) {
  const router = useRouter()

  useEffect(() => {
    const handleRouteChange = () => {
      window.fbq?.('track', 'PageView')
    }
    router.events.on('routeChangeComplete', handleRouteChange)
    return () => router.events.off('routeChangeComplete', handleRouteChange)
  }, [router.events])

  return (
    <>
      <Script id="fb-pixel" strategy="afterInteractive">
        {`...pixel code...`}
      </Script>
      <Component {...pageProps} />
    </>
  )
}
```

### Shopify

**Native pixel (recommended):**
Shopify Admin > Online Store > Preferences > Facebook Pixel ID

This is the simplest path. Shopify handles:
- Base code on all pages
- Standard ecommerce events (ViewContent, AddToCart, InitiateCheckout, Purchase)
- Customer data matching on logged-in users

**Native CAPI:**
Install the Meta app from Shopify App Store. Under "Data sharing settings" > select "Maximum". This enables CAPI automatically with maximum matching parameters.

**Custom events via theme:**
For events Shopify doesn't fire natively, add to theme.liquid:

```liquid
{% if template == 'product' %}
<script>
  document.querySelector('[name="add"]').addEventListener('click', function() {
    fbq('track', 'AddToCart', {
      content_ids: ['{{ product.id }}'],
      content_type: 'product',
      value: {{ product.price | divided_by: 100.0 }},
      currency: '{{ shop.currency }}'
    });
  });
</script>
{% endif %}
```

**Common gotchas:**
- The Shopify checkout domain (checkout.shopify.com) is separate from your storefront -- the pixel carries over but test it explicitly
- Do NOT add pixel code manually if also using the Meta app -- results in double-firing
- For headless Shopify (Hydrogen/custom frontend), treat as Next.js/custom implementation

### WordPress / WooCommerce

**Base code:**
Add via functions.php, header plugin, or child theme:

```php
add_action('wp_head', function() {
  // Only output pixel code (not the fbq calls -- they come separately)
}, 1);  // Priority 1 = early in head
```

**WooCommerce hooks for events:**
- `woocommerce_before_single_product` -- ViewContent
- `woocommerce_add_to_cart` -- AddToCart
- `woocommerce_before_checkout_form` -- InitiateCheckout
- `woocommerce_thankyou` -- Purchase (fires on thank-you page)
- `woocommerce_payment_complete` -- Alternative Purchase trigger

**Hashing in PHP:**
```php
hash('sha256', strtolower(trim($email)));
```

**Common gotchas:**
- WP Caching (WP Rocket, W3 Total Cache) can prevent pixel from firing dynamically -- exclude checkout/thank-you pages from page caching
- The `woocommerce_thankyou` hook fires on page load, not payment confirmation -- use `woocommerce_payment_complete` for webhook-based CAPI to avoid re-firing on refresh
- Multisite installations may need pixel on each subsite separately

### Webflow

Webflow is entirely client-side from a pixel/CAPI perspective. You cannot run server code.

**Pixel:** Add to Site Settings > Custom Code > Head Code (fires on all pages).

**CAPI:** Requires an external webhook handler. Options:
- n8n self-hosted (best for Emerald clients -- use Emerald's n8n instance)
- Make (Integromat)
- Zapier (premium tier for custom webhooks)
- Your own server endpoint

**Pattern:**
1. Form submission fires a `fetch()` to your n8n webhook URL
2. n8n receives the payload, hashes PII, calls Meta CAPI
3. n8n reads IP from request headers (x-forwarded-for or x-real-ip)

**Common gotchas:**
- Webflow forms submit to Webflow's servers -- you can't intercept them natively without JavaScript override
- Use form `submit` event listener with `preventDefault()` if you need to capture form data before submission
- Webflow's JavaScript loads async -- ensure pixel code is in Site Settings head, not page head embed (page embeds load later)

### GoHighLevel (GHL)

**Pixel:** Settings (or Funnel Settings) > Tracking > Facebook Pixel ID.

**CAPI:** Settings > Integrations > Facebook > Connect > enable Conversions API. GHL sends server-side events for form submissions, bookings, and payments automatically.

**When native CAPI is insufficient:**
- Use Workflow > Action > Webhook to send custom CAPI events
- GHL provides contact fields: email, phone, first_name, last_name, ip_address, user_agent

**Webhook body for GHL:**
GHL uses its own templating language. Hash functions may not be native -- use an n8n intermediary to hash before calling Meta if needed.

**Common gotchas:**
- GHL's native CAPI integration sends with slight delay (seconds to minutes) -- not real-time
- Attribution window in GHL reporting vs. Meta may differ -- cross-reference in Events Manager
- Multiple contact records for same email can cause duplicate events -- set up deduplication in workflows
- Test native CAPI with `capi-test.sh` before relying on it -- GHL integration has had reliability issues

### ClickFunnels 2.0

**Pixel:** Funnel Settings > Tracking > Facebook Pixel.

**CAPI:** Workspace Settings > Integrations > Meta. Newer feature -- may be in beta. Check that it's actually sending by using `capi-test.sh`.

**Custom code:** Each funnel step has a "Head Tracking Code" section. Use for advanced matching and custom event overrides.

**Order bumps and upsells:** Each bump/upsell fires its own Purchase event. Ensure event_ids are unique per transaction (include the specific offer SKU in the event_id).

**Common gotchas:**
- CF2's order flow can fire multiple Purchase events for a single session (main offer + bumps) -- this is expected behavior, not a bug
- The thank-you page URL contains order_id -- capture it for deduplication
- CF2's pixel implementation may fire Purchase before payment is fully processed -- verify timing

### Custom / Vanilla JS

Full control. You implement everything.

**Pixel base code:** Standard script tag in `<head>`. See Section 3.

**Event tracking pattern:**
```javascript
// On any conversion event:
const eventId = generateEventId(); // your ID generation function
const fbp = getCookie('_fbp');
const fbc = getCookie('_fbc') || buildFbcFromUrl();

// 1. Fire browser pixel
fbq('track', 'EventName', customData, { eventID: eventId });

// 2. Fire CAPI via your server endpoint
fetch('/your-capi-endpoint', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    eventName: 'EventName',
    eventId: eventId,
    fbp: fbp,
    fbc: fbc,
    userAgent: navigator.userAgent,
    url: window.location.href,
    // any user data you have
  })
});
```

**Server endpoint (any language) calls:**
```
POST https://graph.facebook.com/v19.0/{pixel_id}/events?access_token={token}
Content-Type: application/json
```

---

## 13. Testing and Verification

### Test Events tool (Events Manager)

The fastest way to verify CAPI events are arriving:

1. Events Manager > Data Sources > [Pixel] > Test Events tab
2. Enter your test_event_code in the field
3. Run `capi-test.sh PIXEL_ID TEST12345` (using matching test code)
4. Events appear within 60-120 seconds
5. Verify event_name, user_data fields, and custom_data look correct

**Important:** Do not use test_event_code in production. Remove it before going live. Events sent with test_event_code don't affect campaign data.

### Pixel Helper Chrome extension

Install "Meta Pixel Helper" from Chrome Web Store.

Shows:
- Which pixels are on the page
- Which events are firing and when
- What data is in each event
- Any pixel errors (bad pixel ID, invalid event data)

Use to verify browser pixel is firing correctly before troubleshooting CAPI.

### Events Manager diagnostics

Events Manager > Data Sources > [Pixel] > Diagnostics tab shows:
- Missing parameter warnings
- Deduplication rates (tells you if both pixel and CAPI are firing)
- Invalid event format errors
- Domain verification issues

**Key metrics to check:**
- Deduplication rate: should be > 0 if CAPI is running alongside pixel (means Meta found matching events)
- If dedup rate is 0 and you have both pixel and CAPI: event_id mismatch or CAPI not arriving

### curl testing

Test a specific CAPI call from command line:

```bash
curl -s -X POST \
  "https://graph.facebook.com/v19.0/PIXEL_ID/events?access_token=$META_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": [{
      "event_name": "Purchase",
      "event_time": '"$(date +%s)"',
      "event_id": "test_'"$(date +%s)"'",
      "event_source_url": "https://test.example.com/checkout",
      "action_source": "website",
      "user_data": {
        "em": "'"$(echo -n 'test@example.com' | sha256sum | cut -d' ' -f1)"'",
        "client_ip_address": "127.0.0.1",
        "client_user_agent": "curl/test"
      },
      "custom_data": {"currency": "USD", "value": 1.00}
    }],
    "test_event_code": "TEST12345"
  }' | jq .
```

Expected response:
```json
{
  "events_received": 1,
  "fbtrace_id": "AbcDef123..."
}
```

---

## 14. Common Mistakes

### 1. No event_id (double counting)

**Symptom:** Conversion volume in Ads Manager is 1.5x-2x what you expect. ROAS looks too good.
**Fix:** Add event_id to both pixel and CAPI. Must be the same value for the same event occurrence.

### 2. Sending unhashed PII

**Symptom:** CAPI returns an error about invalid user_data format. Or worse -- silently accepts unhashed data that Meta can't use.
**Fix:** Hash ALL of these before sending: em, ph, fn, ln, ct, st, zp, country, external_id, db, ge. Do NOT hash: client_ip_address, client_user_agent, fbp, fbc.

### 3. Wrong action_source

**Symptom:** Events appear in Events Manager but aren't attributed to website traffic.
**Fix:** Use `"action_source": "website"` for web-triggered events. Other valid values: email, app, phone_call, chat, physical_store, system_generated.

### 4. Stale fbp/fbc values

**Symptom:** Low click attribution even though you're passing fbc.
**Fix:** Read fbp and fbc at event time, not at page load. Cookies may be set after page load when pixel initializes.

**Also:** If the user visited via an ad link (has fbclid in URL), build fbc from the current fbclid: `fb.1.{timestamp}.{fbclid}` -- don't rely on the cookie being set yet.

### 5. Not passing IP address and user agent

**Symptom:** EMQ stays low despite having email.
**Fix:** Every CAPI event must include `client_ip_address` and `client_user_agent`. These come from the HTTP request your server receives from the user. IP from `X-Forwarded-For` or `X-Real-IP` headers (behind load balancer) or `REMOTE_ADDR` directly.

### 6. Over-firing events (multiple times per action)

**Symptom:** More conversions in Meta than in your own analytics. Dedup rate in Events Manager is very high (or events appear duplicate).
**Fix:** Ensure each event fires once per occurrence. Common causes: React re-renders firing useEffect multiple times, webhooks with retry logic, Shopify Order hook firing for each fulfillment update.

### 7. Pixel not on checkout pages

**Symptom:** No InitiateCheckout or Purchase events.
**Fix:** Ensure pixel base code is on checkout/thank-you pages. Shopify checkout uses a separate domain -- verify pixel loads there. Some cookie consent tools block pixel before consent -- ensure checkout pages have pre-granted consent or use CAPI as fallback.

### 8. Using user token instead of system user token for CAPI

**Symptom:** CAPI works initially, then stops after 60 days.
**Fix:** System User tokens don't expire. Generate one in Business Manager > System Users. This is the production standard for CAPI.

### 9. Testing with test_event_code in production

**Symptom:** Conversions don't register in campaign reporting.
**Fix:** Remove `test_event_code` from production CAPI calls. Test events are isolated from campaign data.

### 10. Low EMQ on ViewContent/PageView and treating it as a problem

**Reality:** It's normal. ViewContent and PageView fire for anonymous users who haven't provided any identifying info. Focus EMQ optimization on Lead and Purchase events where you have user data.

---

## 15. Complete Audit Checklist

Run this monthly for every active pixel.

### Pixel Installation
- [ ] Pixel base code on every page (including checkout, thank-you)
- [ ] PageView fires on every page (check Pixel Helper)
- [ ] No duplicate pixel initialization (one init call per page)
- [ ] Domain verified in Business Manager
- [ ] Pixel not blocked by cookie consent before consent (or exempted for CAPI)

### Events Firing
- [ ] ViewContent fires on product/content pages
- [ ] AddToCart fires on add to cart action
- [ ] InitiateCheckout fires when checkout begins
- [ ] Purchase fires on thank-you / order confirmation page
- [ ] Lead fires on form submissions
- [ ] All events have correct custom_data (value, currency for Purchase/Lead)

### Advanced Matching
- [ ] Email enabled in automatic matching (check Pixel settings)
- [ ] Phone enabled in automatic matching
- [ ] First + last name enabled
- [ ] Email passed in CAPI user_data for Purchase and Lead events
- [ ] Phone passed in CAPI user_data where available
- [ ] Geographic fields included in CAPI where available

### CAPI
- [ ] CAPI sending events (verify with capi-test.sh)
- [ ] System User token in use (not user token)
- [ ] Token has ads_management permission
- [ ] FBP cookie passed in every CAPI event
- [ ] FBC cookie passed when available
- [ ] IP address passed (from request headers, not client-provided)
- [ ] User agent passed

### Deduplication
- [ ] event_id present in both pixel and CAPI calls
- [ ] event_id is the same value for matching pixel + CAPI events
- [ ] Deduplication rate > 0 in Events Manager Diagnostics

### EMQ Scores
- [ ] Purchase EMQ: target 9.3+
- [ ] Lead EMQ: target 8.0+
- [ ] Check in Events Manager > Overview (not just from emq-check.sh estimate)
- [ ] Review EMQ per event type (not just average)

### Data Quality
- [ ] No events double-counting (check Ads Manager vs internal analytics)
- [ ] No events firing at wrong time (e.g., Purchase on cart page)
- [ ] Conversion values accurate (correct currency, correct amount)
- [ ] Events Manager Diagnostics shows no critical errors

---

## 16. API Reference

### List pixels for an account

```
GET https://graph.facebook.com/v19.0/act_{account_id}/adspixels
  ?fields=name,id,last_fired_time,is_capi_setup
  &access_token={token}
```

### Get pixel config

```
GET https://graph.facebook.com/v19.0/{pixel_id}
  ?fields=name,automatic_matching_fields,first_party_cookie_status,data_use_setting,code,is_capi_setup
  &access_token={token}
```

### Get pixel event stats

```
GET https://graph.facebook.com/v19.0/{pixel_id}/stats
  ?start_time={unix_timestamp}
  &aggregation=event
  &access_token={token}
```

Aggregation options: `event` (by event name), `device` (by device type), `browser` (by browser).

### Send CAPI event

```
POST https://graph.facebook.com/v19.0/{pixel_id}/events
  ?access_token={token}

Body: {
  "data": [ ...event objects... ],
  "test_event_code": "TESTXXX"  // optional -- remove in production
}
```

Response:
```json
{
  "events_received": 1,
  "messages": [],
  "fbtrace_id": "AbcDef123..."
}
```

Error response:
```json
{
  "error": {
    "message": "Invalid access token",
    "type": "OAuthException",
    "code": 190,
    "fbtrace_id": "AbcDef123..."
  }
}
```

### Check system user permissions

```
GET https://graph.facebook.com/v19.0/me
  ?fields=name,id
  &access_token={token}
```

### Common error codes

| Code | Meaning | Fix |
|------|---------|-----|
| 190 | Invalid/expired token | Generate new system user token |
| 200 | Permission denied | Token needs ads_management scope |
| 10 | Permission denied | Pixel not accessible with this token |
| 100 | Invalid parameter | Check event payload structure |
| 368 | Blocked | Account may be restricted |
