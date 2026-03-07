# Local SEO Reference

## Overview

Local SEO determines visibility in Google's Map Pack (the 3-pack of local business results), Google Maps, and local organic results. The dominant platform is Google Business Profile (GBP). In 2025, GBP data feeds directly into AI Overviews — a well-optimized profile gets surfaced in both traditional local results and AI-generated answers for local queries.

---

## Google Business Profile (GBP) Optimization

### Complete Profile Checklist

Google rewards profiles that are 100% complete. Each filled field is a signal.

**Business Identity (critical)**:
- [ ] Business name (exact legal/DBA name — no keyword stuffing)
- [ ] Primary category (most important ranking factor — choose the most specific correct category)
- [ ] Secondary categories (add all relevant ones, up to 10)
- [ ] Business description (750 characters max — include primary keywords naturally in first 250)
- [ ] Website URL
- [ ] Phone number (local number preferred over toll-free)
- [ ] Address (exact match to your website, citations, and legal documents)

**Hours (critical)**:
- [ ] Regular hours for all 7 days
- [ ] Special hours (holidays, events)
- [ ] "More hours" if relevant (happy hour, senior hours, etc.)

**Service Area** (if you serve customers at their location):
- [ ] Define service area cities/regions (instead of or in addition to physical address)
- [ ] Remove physical address from display if home-based business

**Products and Services**:
- [ ] Add all services with descriptions and prices where applicable
- [ ] Add products if applicable (enables Product carousel in local results)
- [ ] Menu link (for restaurants, cafes)

**Attributes** (varies by category):
- [ ] Payment options
- [ ] Accessibility features
- [ ] Amenities (WiFi, parking, etc.)
- [ ] Health and safety attributes
- [ ] Identifies as: women-owned, veteran-owned, LGBTQ+ friendly, etc.

**Media**:
- [ ] Cover photo (1080x608px minimum, represents brand)
- [ ] Logo (250x250px minimum)
- [ ] Exterior photos (at least 3 — helps users find you)
- [ ] Interior photos (at least 3 — builds trust)
- [ ] Team/staff photos (humanizes business)
- [ ] Product/service photos (at least 5-10)
- [ ] Videos (up to 30 seconds, 75MB max)

### Business Description Best Practices

750 characters max. Formula:
1. **Opening**: What you do + who you serve (include primary keyword)
2. **Middle**: Key differentiators (years in business, specialization, notable clients/awards)
3. **Close**: Location and service area (include city/region naturally)

Example structure:
> "[Business Name] is a [primary category] serving [city/region] since [year]. We specialize in [key services with keywords]. [Differentiator: award, certification, unique approach]. Located in [neighborhood], we serve [geographic scope]. [Call to action or value proposition]."

**Avoid**: Keyword stuffing, URLs, promotional language ("best," "#1"), information that changes (promotions, temporary offers).

### Category Selection Strategy

Primary category is the most important GBP ranking factor. Rules:
- Only one primary category
- Be as specific as possible (choose "Italian Restaurant" not "Restaurant")
- Match what customers search for, not your internal business description
- Check competitors in Map Pack — what categories are they using?

Secondary categories:
- Add all services you genuinely provide
- Each secondary category makes you eligible for additional search queries
- Limit to what you actually do (irrelevant categories can hurt relevance)

### Photo Optimization

- Upload new photos regularly (signals active profile)
- Use geotagged photos when possible (add GPS coordinates in EXIF data)
- File names should be descriptive (not IMG_4821.jpg)
- Minimum resolution: 720x720px for most photos
- Google's own data: Businesses with 100+ photos get 520% more calls

Photo frequency target: Add 1-2 new photos per week minimum.

### Q&A Management

GBP Q&A is publicly crowdsourced — anyone can ask or answer. This is a risk.

**Best practice — seed your own Q&As**:
1. Log out of your Google account (or use a different device)
2. Ask questions customers commonly ask ("Do you offer [service]?", "Is parking available?")
3. Log back in as the business owner and answer comprehensively
4. Upvote the most important Q&As

**Monitor incoming questions**: Set up notifications. Unanswered questions get answered by strangers — often incorrectly.

### GBP Posts

Posts appear in Knowledge Panel and Maps. Types:
- **Update**: General news, announcements (expires in 6 months)
- **Offer**: Promotions with start/end dates, coupon codes
- **Event**: Specific events with dates and times

Post best practices:
- Post 1-2x per week minimum (active profiles rank better)
- Include a high-quality image (1200x900px recommended)
- First 100 characters are most visible — front-load the message
- Add a Call to Action button (Learn More, Call Now, Book, Order)
- Use natural keywords (not stuffed)

---

## Local Citation Consistency (NAP)

### What is NAP?

**N**ame, **A**ddress, **P**hone number. Google cross-references your business info across the web. Inconsistencies (abbreviations, suite number formats, old phone numbers) confuse Google and suppress rankings.

**NAP consistency rule**: The exact string must match everywhere:
- "Suite 400" vs "Ste. 400" vs "#400" — pick one, use everywhere
- "Street" vs "St." — pick one
- "(555) 123-4567" vs "555-123-4567" — pick one
- Business name with or without "LLC" / "Inc." — pick one

### Citation Audit Process

1. Run a NAP audit (BrightLocal, Whitespark, or Moz Local)
2. Find all citations — directories, aggregators, industry sites
3. Identify inconsistencies
4. Correct in priority order: aggregators first (they distribute to hundreds of directories)

**Data aggregators (correct these first — they feed everything else)**:
- Data Axle (formerly InfoUSA)
- Localeze (Neustar)
- Foursquare (feeds Apple Maps, Samsung, and dozens of apps)
- Acxiom

### Priority Citation Directories

**Tier 1 (mandatory)**:
| Directory | Notes |
|-----------|-------|
| Google Business Profile | Primary ranking factor |
| Apple Maps (Apple Business Connect) | iOS default maps |
| Bing Places | Microsoft search + Cortana |
| Yelp | High-authority, consumer trust |
| Facebook Business Page | Social + local signal |
| BBB (Better Business Bureau) | Trust signal |
| Foursquare | Data aggregator for many apps |
| Yellow Pages (YP.com) | Legacy authority |

**Tier 2 (industry-dependent)**:
- LinkedIn (B2B businesses)
- Houzz (home services)
- Healthgrades / Zocdoc (healthcare)
- Avvo / Justia (legal)
- TripAdvisor / OpenTable (hospitality/restaurants)
- Angi / HomeAdvisor (contractors)
- Thumbtack (service businesses)

### Citation Building Process

1. Claim and verify GBP first
2. Submit to data aggregators (use Yext, BrightLocal, or Moz Local for automation)
3. Manually claim Tier 1 directories
4. Research industry-specific directories (search "[industry] + directory")
5. Local directories (chamber of commerce, local news site business listings)

---

## LocalBusiness Schema Markup

Schema.org/LocalBusiness markup helps Google extract your NAP, hours, and services for Knowledge Panel and AI Overviews.

### Complete JSON-LD Template

```json
{
  "@context": "https://schema.org",
  "@type": "LocalBusiness",
  "name": "Business Name",
  "image": "https://example.com/images/business-photo.jpg",
  "@id": "https://example.com/#business",
  "url": "https://example.com",
  "telephone": "+15551234567",
  "address": {
    "@type": "PostalAddress",
    "streetAddress": "123 Main Street, Suite 400",
    "addressLocality": "City Name",
    "addressRegion": "CA",
    "postalCode": "90210",
    "addressCountry": "US"
  },
  "geo": {
    "@type": "GeoCoordinates",
    "latitude": 34.0522,
    "longitude": -118.2437
  },
  "openingHoursSpecification": [
    {
      "@type": "OpeningHoursSpecification",
      "dayOfWeek": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
      "opens": "09:00",
      "closes": "18:00"
    },
    {
      "@type": "OpeningHoursSpecification",
      "dayOfWeek": "Saturday",
      "opens": "10:00",
      "closes": "16:00"
    }
  ],
  "priceRange": "$$",
  "servesCuisine": "Italian",
  "hasMap": "https://maps.google.com/?cid=YOUR_CID",
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": "4.7",
    "reviewCount": "342"
  },
  "sameAs": [
    "https://www.facebook.com/yourbusiness",
    "https://www.yelp.com/biz/yourbusiness",
    "https://twitter.com/yourbusiness"
  ]
}
```

**For service businesses (no physical storefront)**:
- Remove `address` block or set `"@type": "ServiceArea"` instead
- Add `"areaServed"` with city/region names or GeoCircle/GeoShape

**For multi-location businesses**:
- Each location gets its own LocalBusiness schema
- Use `"@type": ["LocalBusiness", "DepartmentStore"]` pattern for chains
- Link to parent organization with `"parentOrganization"` property

---

## Review Generation Strategy

Reviews are the #3 Map Pack ranking factor (behind relevance and proximity). They also feed directly into GBP's AI Overview appearance.

### Timing the Ask

Best times to request a review:
- Immediately after service completion (highest conversion)
- Within 24 hours for appointment-based services
- After first successful delivery/result for ongoing services
- Never at the moment of payment (feels transactional)

### Review Request Templates

**Email template (short)**:
> "Hi [Name], thank you for choosing [Business]. We hope we exceeded your expectations! If you have a moment, a quick Google review helps other [city] residents find us: [Review Link]. It takes less than 2 minutes."

**SMS template (highest open rate)**:
> "[Business]: Thanks for your visit today! If you're happy with [service], a Google review helps us grow. Tap here: [Short Link]"

**In-person card (QR code)**:
- Print QR code linking to Google review form
- Use go.page.link or Google's own review link shortener

### Creating Google Review Link

1. Search your business name in Google
2. In Knowledge Panel, click "Get more reviews"
3. Copy the short link Google provides
4. Or construct manually: `https://search.google.com/local/writereview?placeid=YOUR_PLACE_ID`

### Responding to Reviews

**Positive reviews**:
- Respond to all 5-star reviews (signals engagement to Google)
- Personalize (mention their specific service/product)
- Keep under 100 words
- Include 1-2 keywords naturally

**Negative reviews**:
- Respond within 24-48 hours
- Never argue, get defensive, or reveal private info
- Acknowledge concern + offer to resolve offline
- Formula: "We're sorry to hear about your experience with [issue]. This isn't the standard we hold ourselves to. Please contact us at [email/phone] so we can make it right."
- Never offer compensation publicly (appears as bribery)

### Platforms to Prioritize

Rank order by impact on local SEO:
1. Google (primary signal for Map Pack)
2. Yelp (trust signal, feeds into Bing/Apple)
3. Facebook (social trust signal)
4. Industry-specific (TripAdvisor, Healthgrades, Houzz, etc.)
5. BBB (trust/authority signal)

---

## Map Pack Ranking Factors

Google's local algorithm uses three primary signals:

### 1. Relevance
How well your business matches the search query.

Optimization levers:
- GBP categories (most important)
- GBP description with keywords
- Website content (your site still matters for local)
- Service/product keywords in GBP
- Review content (keywords in reviews help)

### 2. Distance
How close the searcher is to the business. You cannot directly control this.

Indirect optimization:
- Ensure your address is precise and verified
- Service area businesses: define realistic service area (don't over-expand)
- Multi-location: create separate GBP for each location

### 3. Prominence
How well-known and authoritative your business is.

Optimization levers:
- Number and quality of reviews (and responses)
- Number of citations across the web
- Backlinks to your website
- Overall website authority
- Wikipedia article (if applicable)
- Press coverage and mentions

**2025 addition**: AI search surfaces businesses with higher prominence in AI-generated local recommendations.

---

## Multi-Location Management

For businesses with 2+ locations:

**GBP Management**:
- Each location needs a separate GBP listing
- Bulk management via Google Business Profile Manager
- Consistent naming convention: "[Business Name] - [City]" or "[Business Name] [Neighborhood]"
- Each location gets its own category, phone number, and photos

**Website structure**:
- Dedicated location page for each location (not thin duplicate content)
- URL structure: `/locations/[city]/` or `[city].example.com`
- Each page: unique content, local phone number, embedded Google Map, LocalBusiness schema
- Location hub page: `/locations/` with links to all location pages

**Tools for bulk management**:
- Google Business Profile Manager (free)
- Yext (enterprise, syncs to 200+ directories)
- BrightLocal (auditing + management)
- Whitespark (citation building)

---

## Common Mistakes

- **Keyword stuffing in business name**: Violates GBP guidelines and risks suspension (e.g., "Joe's Plumbing - Best Plumber NYC" when business name is "Joe's Plumbing")
- **Inconsistent NAP**: Old phone number on 1 directory undermines citation consistency
- **Ignoring Q&A**: Competitors or random users answering incorrectly
- **No review responses**: 89% of consumers read business responses to reviews
- **Service area too broad**: Claiming a 200-mile radius hurts relevance for local searches
- **Same photos on all locations**: Google can detect duplicate media across listings
- **No location pages on website**: GBP without a supporting local website page limits local organic rankings
- **Neglecting GBP posts**: Active profiles signal trustworthiness to both Google and users
