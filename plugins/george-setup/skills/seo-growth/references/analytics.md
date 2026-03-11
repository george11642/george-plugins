# Analytics & Tracking Reference

## Core Principles

1. **Track for decisions, not data** -- every event should inform a decision. Avoid vanity metrics.
2. **Start with questions** -- what do you need to know? Work backwards to what to track.
3. **Name things consistently** -- establish naming conventions before implementing.
4. **Maintain data quality** -- validate implementation, monitor for issues. Clean data > more data.

---

## Tracking Plan Framework

Define events in this format before implementing:

| Event Name | Category | Properties | Trigger | Conversion? |
|------------|----------|------------|---------|-------------|
| signup_completed | User | method, plan | Signup success | Yes |

### Event Naming Convention

Use **Object_Action** format (recommended), lowercase with underscores:

```
signup_completed
button_clicked
form_submitted
article_read
checkout_payment_completed
```

Rules:
- Be specific: `cta_hero_clicked` not `button_clicked`
- Include context in properties, not event name
- No spaces or special characters
- Document all decisions

---

## Essential Events by Site Type

### Marketing Site

**Engagement**: page_view (enhanced), scroll_depth (25/50/75/100%), cta_clicked (button_text, location), video_played (video_id, duration), form_started, form_submitted (form_type), resource_downloaded (resource_name), outbound_link_clicked

**Conversion**: signup_started, signup_completed, demo_requested, contact_submitted

### Product / SaaS

**Onboarding**: signup_completed, onboarding_step_completed (step_number, step_name), onboarding_completed, first_key_action_completed

**Core Usage**: feature_used (feature_name), action_completed (action_type), session_started/ended

**Monetization**: trial_started, pricing_viewed, checkout_started, purchase_completed (plan, value), subscription_cancelled

### E-commerce

**Browsing**: product_viewed (product_id, category, price), product_list_viewed (list_name), product_searched (query, results_count)

**Cart**: product_added_to_cart, product_removed_from_cart, cart_viewed

**Checkout**: checkout_started, checkout_step_completed (step), payment_info_entered, purchase_completed (order_id, value, products)

---

## Event Properties

### Standard Properties

| Category | Properties |
|----------|-----------|
| **Page** | page_title, page_location, page_referrer, content_group |
| **User** | user_id (if logged in), user_type (free/paid), account_id, plan_type |
| **Campaign** | source, medium, campaign, content, term |
| **Product** | product_id, product_name, category, price, quantity, currency |
| **Timing** | timestamp, session_duration, time_on_page |

Rules: Use consistent names, include relevant context, do not duplicate GA4 automatic properties, never include PII, document expected values.

---

## GA4 Implementation

### Setup
- One data stream per platform (web, iOS, Android)
- Enable enhanced measurement (auto-tracks: page_view, scroll, outbound_click, site_search, video_engagement, file_download)
- Use Google's predefined events when possible for enhanced reporting

### Custom Events

```javascript
// gtag.js
gtag('event', 'signup_completed', {
  'method': 'email',
  'plan': 'free'
});

// Google Tag Manager (dataLayer)
dataLayer.push({
  'event': 'signup_completed',
  'method': 'email',
  'plan': 'free'
});
```

### Conversions Setup
1. Collect event in GA4
2. Mark as conversion in Admin > Events
3. Set counting method (once per session or every occurrence)
4. Import to Google Ads if running paid campaigns

### Custom Dimensions and Metrics
Use when you need to segment by or aggregate properties beyond standard parameters. Create in Admin > Custom definitions. Scopes: Event, User, or Item.

---

## Google Tag Manager (GTM)

### Container Structure

| Component | Examples |
|-----------|---------|
| **Tags** | GA4 Configuration (base), GA4 Event tags, conversion pixels (Facebook, LinkedIn) |
| **Triggers** | Page View (DOM Ready / Window Loaded), Click (All Elements / Just Links), Form Submission, Custom Events |
| **Variables** | Built-in (Click Text, URL, Page Path), Data Layer variables, JavaScript variables, Lookup tables |

### Folder Organization

Use GTM folders to keep large containers manageable. Recommended folder structure:

```
GTM Container
├── 📁 GA4 — Base & Config
│   ├── GA4 Configuration Tag
│   └── GA4 Enhanced Measurement overrides
├── 📁 GA4 — Marketing Events
│   ├── GA4 Event — CTA Clicked
│   ├── GA4 Event — Form Submitted
│   └── GA4 Event — Resource Downloaded
├── 📁 GA4 — Product Events
│   ├── GA4 Event — Signup Completed
│   ├── GA4 Event — Trial Started
│   └── GA4 Event — Purchase Completed
├── 📁 Paid Media Pixels
│   ├── Meta Pixel — PageView
│   ├── Meta Pixel — Purchase
│   └── LinkedIn Insight Tag
├── 📁 Utilities
│   ├── Scroll Depth Trigger
│   └── Timer Trigger (30s engagement)
└── 📁 Variables — Custom
    ├── DLV — user_id
    ├── DLV — plan_type
    └── DLV — ecommerce object
```

**Naming convention** (always follow for searchability):
- Tags: `[Platform]_[Type]_[Event/Description]` — e.g., `GA4_Event_SignupCompleted`, `Meta_Pixel_Purchase`
- Triggers: `[Type]_[Description]` — e.g., `Click_SignupButton`, `FormSubmit_Contact`, `CustomEvent_Purchase`
- Variables: `[Type]_[Description]` — e.g., `DLV_UserID`, `JS_PageCategory`, `LT_ContentGroup`

### Best Practices
- Use folders to organize tags by purpose
- Naming convention: Tag_Type_Description (e.g., GA4_Event_SignupCompleted)
- Version notes on every publish (include: what changed, why, who)
- Preview mode for testing before publish
- Workspaces for team collaboration (never publish directly from Default workspace in teams)

### Data Layer Patterns

**Custom event:**
```javascript
dataLayer.push({
  'event': 'form_submitted',
  'form_name': 'contact',
  'form_location': 'footer'
});
```

**User properties (push once on page load when user is identified):**
```javascript
dataLayer.push({
  'user_id': '12345',
  'user_type': 'premium',
  'plan_type': 'pro',
  'account_id': 'ACC789'
});
```

**E-commerce: product added to cart:**
```javascript
dataLayer.push({
  'event': 'add_to_cart',
  'ecommerce': {
    'currency': 'USD',
    'value': 49.99,
    'items': [{
      'item_id': 'SKU123',
      'item_name': 'Pro Plan Monthly',
      'item_category': 'Subscription',
      'price': 49.99,
      'quantity': 1
    }]
  }
});
```

**E-commerce: purchase (most important for conversion tracking):**
```javascript
dataLayer.push({
  'event': 'purchase',
  'ecommerce': {
    'transaction_id': 'T12345',        // Unique order ID — critical to prevent duplicate conversions
    'value': 99.99,
    'tax': 0,
    'shipping': 0,
    'currency': 'USD',
    'coupon': 'SPRING20',              // Optional
    'items': [{
      'item_id': 'SKU123',
      'item_name': 'Pro Plan Annual',
      'item_category': 'Subscription',
      'price': 99.99,
      'quantity': 1
    }]
  }
});
```

**SaaS signup completion:**
```javascript
dataLayer.push({
  'event': 'signup_completed',
  'method': 'email',                   // email | google | github | sso
  'plan': 'free',                      // free | starter | pro | business
  'source': 'homepage_hero_cta'        // where the signup was initiated
});
```

**Note**: Always clear the ecommerce object before pushing new ecommerce events to prevent data bleeding between events:
```javascript
dataLayer.push({ 'ecommerce': null });  // Clear previous ecommerce data
dataLayer.push({
  'event': 'view_item',
  'ecommerce': { ... }
});
```

---

## UTM Parameter Strategy

### Standard Parameters

| Parameter | Purpose | Example |
|-----------|---------|---------|
| utm_source | Traffic origin | google, facebook, newsletter |
| utm_medium | Marketing medium | cpc, email, social, referral |
| utm_campaign | Campaign name | spring_sale, product_launch |
| utm_content | Differentiate versions | hero_cta, sidebar_link |
| utm_term | Paid search keywords | running+shoes |

### Rules
- **Lowercase everything** (google, not Google)
- **Use underscores or hyphens consistently** (pick one, stick with it)
- **Be specific but concise** (blog_footer_cta, not cta1)
- **Document all UTMs** in a shared spreadsheet with: Campaign, Source, Medium, Content, Full URL, Owner, Date

---

## Standard Event Properties Matrix

Use this matrix as a reference when building tracking plans. Properties are grouped by category; include the ones relevant to each event.

| Category | Property | Format | Example | Notes |
|----------|---------|--------|---------|-------|
| **Page** | page_title | string | "Pricing — Acme" | Auto from GA4 enhanced measurement |
| **Page** | page_location | string (URL) | "https://acme.com/pricing" | Auto from GA4 |
| **Page** | page_referrer | string (URL) | "https://google.com" | Auto from GA4 |
| **Page** | content_group | string | "blog", "docs", "marketing" | Custom dimension — set via GTM |
| **User** | user_id | string | "usr_abc123" | Never use email; use internal ID |
| **User** | user_type | string | "free", "trial", "paid", "admin" | |
| **User** | plan_type | string | "starter", "pro", "business" | |
| **User** | account_id | string | "acc_xyz789" | For B2B — the organization ID |
| **Campaign** | source | string | "google", "newsletter" | From UTM or GA4 auto-detection |
| **Campaign** | medium | string | "cpc", "email", "organic" | |
| **Campaign** | campaign | string | "spring_launch_2025" | |
| **Campaign** | content | string | "hero_cta", "sidebar_banner" | Differentiates ad/link variants |
| **Interaction** | button_text | string | "Start Free Trial" | For click events |
| **Interaction** | button_location | string | "hero", "nav", "footer" | Where on page |
| **Interaction** | form_name | string | "contact", "demo_request" | For form events |
| **Interaction** | form_location | string | "footer", "modal", "inline" | |
| **Interaction** | video_id | string | "yt_abc123" | For video events |
| **Interaction** | video_duration | number (seconds) | 185 | |
| **Product** | item_id | string | "plan_pro_monthly" | GA4 e-commerce format |
| **Product** | item_name | string | "Pro Plan Monthly" | |
| **Product** | item_category | string | "Subscription" | |
| **Product** | price | number | 49.99 | Always use 2 decimal places |
| **Product** | quantity | number | 1 | |
| **Product** | currency | string | "USD" | ISO 4217 format |
| **Transaction** | transaction_id | string | "txn_T12345" | Must be unique per purchase |
| **Transaction** | value | number | 49.99 | Revenue value for conversion tracking |
| **Transaction** | coupon | string | "SPRING20" | Optional |

---

## Debugging and Validation

### Tools

| Tool | Use For |
|------|---------|
| **GA4 DebugView** | Real-time event monitoring. Enable with `?debug_mode=true` or Chrome extension |
| **GTM Preview Mode** | Test triggers, tags, and data layer state before publishing |
| **GA Debugger extension** | Browser-level analytics debugging |
| **Tag Assistant** | Verify tag implementation |
| **dataLayer Inspector+** | Chrome extension to inspect full data layer contents and history |

### Validation Checklist
- [ ] Events firing on correct triggers
- [ ] Property values populating correctly
- [ ] No duplicate events
- [ ] Works across browsers and mobile
- [ ] Conversions recorded correctly
- [ ] User ID passing when logged in
- [ ] No PII leaking into analytics
- [ ] Ecommerce events clear previous data before pushing new events

### Debugging Checklist: 6 Common Issues and Causes

| Problem | Most Likely Causes | How to Diagnose |
|---------|-------------------|----------------|
| **Events not firing** | 1. Trigger misconfigured (wrong element selector, wrong event type) 2. Tag paused or disabled in GTM 3. GTM container not loading on page 4. Consent mode blocking all tags | GTM Preview Mode → check Trigger column. Check browser Network tab for GTM container request. |
| **Wrong property values** | 1. Data layer variable not configured correctly in GTM 2. dataLayer.push() timing (fires before element exists) 3. Variable referencing old element that changed in DOM 4. Wrong variable type (lookup table returns undefined) | GTM Preview Mode → click Variables tab → inspect raw values. Check browser console for dataLayer array. |
| **Duplicate events** | 1. Multiple GTM containers on same page 2. Tag firing on multiple trigger conditions simultaneously 3. GA4 base tag firing alongside duplicate event tag 4. Enhanced measurement + custom event for same action | Filter GA4 DebugView by event name — see if count > 1 per action. Check Triggers tab in GTM Preview. |
| **Conversions not recording** | 1. Event not marked as conversion in GA4 Admin 2. Event fires but GA4 conversion counting is "once per session" and user already converted 3. GA4 data takes 24-48 hours to appear in standard reports | Use GA4 DebugView (real-time) to see if conversion registers immediately. |
| **Events fire in GTM Preview but not in GA4** | 1. GA4 Measurement ID mismatch (dev vs. prod ID) 2. GA4 tag not triggering on same condition as event tag 3. GA4 Configuration tag not loading (it must fire before event tags) | Check GA4 Configuration tag triggers — must fire on All Pages. Verify Measurement ID. |
| **Data missing for some users** | 1. Consent mode blocking tags for non-consenting users 2. Ad blockers preventing GTM or GA4 from loading 3. Timing issue (tag fires before user is identified) | Segment DebugView by session — check if issue is consistent or per-user. |

---

## Privacy and Compliance

### Requirements
- Cookie consent required in EU/UK/CA (GDPR, CCPA, PIPEDA)
- No PII in analytics properties (no emails, names, phone numbers)
- Configure data retention settings in GA4 (Admin > Data Settings > Data Retention — set to 14 months max for most use cases)
- Support user deletion requests (GA4 Admin > Data Deletion Requests)

### Google Consent Mode v2 Implementation

Consent Mode v2 (required for EU from March 2024) uses two new consent types in addition to the original four:

| Consent Type | What It Controls |
|-------------|-----------------|
| `ad_storage` | Cookies for advertising |
| `analytics_storage` | Cookies for analytics (GA4) |
| `ad_user_data` | Sending user data to Google for ads |
| `ad_personalization` | Personalized advertising |
| `functionality_storage` | Cookies for functionality (preferences) |
| `security_storage` | Cookies required for security |

**Implementation pattern with GTM + CMP:**

```javascript
// Step 1: Set default consent state (before GTM loads — in <head>, before GTM snippet)
window.dataLayer = window.dataLayer || [];
function gtag(){dataLayer.push(arguments);}

// Default: deny all for EU users, grant for others (adjust per your legal requirements)
gtag('consent', 'default', {
  'ad_storage': 'denied',
  'analytics_storage': 'denied',
  'ad_user_data': 'denied',
  'ad_personalization': 'denied',
  'functionality_storage': 'denied',
  'security_storage': 'granted',
  'wait_for_update': 500  // Wait 500ms for CMP to update consent
});
```

```javascript
// Step 2: Update consent after user makes choice (called by your CMP)
function updateConsent(consentDecision) {
  gtag('consent', 'update', {
    'ad_storage': consentDecision.marketing ? 'granted' : 'denied',
    'analytics_storage': consentDecision.analytics ? 'granted' : 'denied',
    'ad_user_data': consentDecision.marketing ? 'granted' : 'denied',
    'ad_personalization': consentDecision.marketing ? 'granted' : 'denied',
  });
}
```

**In GTM:**
- Create a Consent Initialization trigger (fires before all others)
- Use built-in Consent State variables to conditionally fire tags
- For GA4: enable "Require consent" on the Configuration tag for analytics_storage

### CMP Integration

Common CMPs and their GTM integration:
- **Cookiebot**: Has official GTM template — auto-maps consent signals
- **OneTrust**: Official GTM integration, fires custom events on consent changes
- **Osano**: Fires `osano_consentChanged` custom event — use as GTM trigger
- **Usercentrics**: Official GTM template

**Whichever CMP you use:**
1. CMP must fire BEFORE GTM's container loads, OR
2. Use Consent Mode v2 defaults (deny all) and let CMP update them

### IP Anonymization

GA4 automatically anonymizes IPs for all EU users. For server-side implementations or older configurations:

```javascript
// GA4 does not require explicit IP anonymization call — it's automatic
// For Universal Analytics (legacy), was: { 'anonymize_ip': true }
// GA4: IP anonymization is always on in EU; configurable in GA4 Admin > Data Collection
```

### Data Minimization Checklist
- [ ] No email addresses in any custom dimensions or event parameters
- [ ] No full names in user properties
- [ ] No IP addresses stored (GA4 handles this automatically)
- [ ] User IDs are pseudonymized internal IDs, not emails
- [ ] No financial data in analytics properties
- [ ] Event property values checked for accidental PII capture (form field values, search queries containing personal info)

---

## Tracking Plan Template

```
# [Site/Product] Tracking Plan

## Overview
- Tools: GA4, GTM
- Last updated: [Date]
- Owner: [Name]

## Events

### Marketing Events
| Event Name | Description | Properties | Trigger |
|------------|-------------|------------|---------|
| signup_started | User initiates signup | source, page | Click signup CTA |
| signup_completed | User completes signup | method, plan | Signup success page |

### Product Events
[Similar table]

## Custom Dimensions
| Name | Scope | Parameter | Description |
|------|-------|-----------|-------------|
| user_type | User | user_type | Free, trial, paid |

## Conversions
| Conversion | Event | Counting | Google Ads |
|------------|-------|----------|------------|
| Signup | signup_completed | Once per session | Yes |

## UTM Convention
[Guidelines from UTM section above]
```
