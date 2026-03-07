# SEO Audit Reference

## Audit Framework

### Schema Markup Detection Limitation

`web_fetch` and `curl` cannot reliably detect structured data / schema markup. Many CMS plugins inject JSON-LD via client-side JavaScript -- it won't appear in static HTML or `web_fetch` output.

**To accurately check schema markup:**
1. Browser tool -- render page and run: `document.querySelectorAll('script[type="application/ld+json"]')`
2. Google Rich Results Test -- https://search.google.com/test/rich-results
3. Screaming Frog export (renders JavaScript)

**Never report "no schema found" based solely on `web_fetch` or `curl`.**

### Priority Order
1. Crawlability & Indexation
2. Technical Foundations
3. On-Page Optimization
4. Content Quality
5. Authority & Links

---

## Technical SEO

### Crawlability
- **Robots.txt**: Check for unintentional blocks, verify sitemap reference
- **XML Sitemap**: Exists, accessible, contains only canonical indexable URLs, updated regularly
- **Site Architecture**: Important pages within 3 clicks, logical hierarchy, no orphan pages
- **Crawl Budget** (large sites): Parameterized URLs, faceted navigation, infinite scroll with pagination fallback

### Indexation
- site:domain.com check vs Search Console coverage
- Noindex tags on important pages
- Canonicals pointing wrong direction
- Redirect chains/loops, soft 404s
- HTTP/HTTPS, www/non-www, trailing slash consistency

### Core Web Vitals
- LCP < 2.5s, INP < 200ms, CLS < 0.1
- TTFB, image optimization, JS execution, CSS delivery, caching, CDN, font loading

### Mobile-Friendliness
- Responsive design, tap target sizes, viewport configured, no horizontal scroll

### Security & HTTPS
- HTTPS everywhere, valid SSL, no mixed content, HSTS header

---

## On-Page SEO

### Title Tags
- Unique per page, primary keyword near beginning, 50-60 chars, compelling, brand at end
- Watch for: duplicates, truncation, keyword stuffing, missing titles

### Meta Descriptions
- Unique per page, 150-160 chars, includes keyword, clear value prop, CTA
- Watch for: duplicates, auto-generated, no compelling reason to click

### Heading Structure
- One H1 per page with primary keyword, logical H1>H2>H3 hierarchy
- Watch for: multiple H1s, skip levels, headings for styling only

### Content Optimization
- Keyword in first 100 words, related keywords natural, sufficient depth
- Thin content: pages with little unique content, tag/category pages with no value

### Image Optimization
- Descriptive file names, alt text on all images, compressed, WebP format, lazy loading

### Internal Linking
- Important pages well-linked, descriptive anchor text, no broken links
- Watch for: orphan pages, over-optimized anchors, important pages buried

---

## Content Quality (E-E-A-T)

- **Experience**: First-hand experience, original insights/data
- **Expertise**: Author credentials visible, accurate information
- **Authoritativeness**: Recognized in space, cited by others
- **Trustworthiness**: Accurate info, transparent business, contact info, HTTPS

---

## Common Issues by Site Type

### SaaS/Product
- Product pages lack depth, blog not integrated, missing comparison pages

### E-commerce
- Thin category pages, duplicate descriptions, missing product schema, faceted navigation duplicates

### Content/Blog
- Outdated content, keyword cannibalization, no topical clustering, poor internal linking

### Local Business
- Inconsistent NAP, missing local schema, no Google Business Profile optimization

---

## Audit Report Structure

1. **Executive Summary**: Health assessment, top 3-5 priorities, quick wins
2. **Technical SEO Findings**: Issue, Impact, Evidence, Fix, Priority per item
3. **On-Page SEO Findings**: Same format
4. **Content Findings**: Same format
5. **Prioritized Action Plan**: Critical fixes > High-impact > Quick wins > Long-term

---

## AI Writing Detection Patterns

Common AI writing tells to avoid in SEO content:
- Overuse of em dashes
- Filler phrases ("In today's fast-paced world", "It's worth noting")
- Overly formal transitions
- Uniform paragraph length
- Generic conclusions

See original: seo-audit/references/ai-writing-detection.md

---

## Tools

**Free**: Google Search Console, PageSpeed Insights, Bing Webmaster Tools, Rich Results Test, Mobile-Friendly Test, Schema Validator

**Paid**: Screaming Frog, Ahrefs, Semrush, Sitebulb, ContentKing
