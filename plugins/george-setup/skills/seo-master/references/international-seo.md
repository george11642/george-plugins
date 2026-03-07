# International SEO Reference

## Overview

International SEO solves two problems: (1) telling search engines which pages target which countries/languages, and (2) ensuring the right version appears for users in different regions. The primary technical implementation is hreflang. Get it wrong and you'll have duplicate content issues, wrong-language results showing for users, and wasted crawl budget.

---

## Domain Structure Decision Tree

This is the most consequential decision in international SEO. It's difficult to reverse.

### Option 1: Country Code Top-Level Domains (ccTLD)

```
example.de  (Germany)
example.fr  (France)
example.co.uk  (United Kingdom)
example.com.au  (Australia)
```

**Geo-targeting signal**: Strongest — Google treats ccTLDs as inherently local
**Link equity**: Each ccTLD is a separate domain — backlinks don't consolidate
**Management overhead**: High — separate properties in GSC, separate SEO efforts per domain
**Cost**: High — domain registration + hosting per country

**When to use**: Large enterprise with dedicated per-country marketing budgets; countries where local brand credibility requires local domain (Germany and .de); highly competitive local markets where you need maximum geo-signal.

### Option 2: Subdomains

```
de.example.com  (Germany)
fr.example.com  (France)
uk.example.com  (United Kingdom)
```

**Geo-targeting signal**: Medium — Google can geo-target subdomains via GSC
**Link equity**: Partial consolidation with main domain (better than ccTLD)
**Management overhead**: Medium — same server/CMS, separate GSC properties
**Cost**: Low — no separate domain costs

**When to use**: Separate technical infrastructure needed per region (e.g., different CMS, different hosting region); team organization matches subdomain structure.

### Option 3: Subfolders (Subdirectories)

```
example.com/de/  (Germany)
example.com/fr/  (France)
example.com/en-gb/  (United Kingdom)
```

**Geo-targeting signal**: Moderate — geo-targeted via hreflang + GSC
**Link equity**: All backlinks to any URL consolidate to the root domain
**Management overhead**: Lowest — single GSC property, single server
**Cost**: Lowest — no additional infrastructure

**When to use**: Recommended for most businesses. Best for: startups/SMBs, businesses without large per-country budgets, sites where link equity consolidation matters, teams without per-country technical teams.

### Decision Matrix

| Factor | ccTLD | Subdomain | Subfolder |
|--------|-------|-----------|-----------|
| Strongest geo-signal | Yes | Moderate | Moderate |
| Link equity consolidation | No | Partial | Yes |
| Setup complexity | High | Medium | Low |
| Annual cost | High | Low | Low |
| Separate content management | Required | Optional | Optional |
| Recommended for most sites | No | No | **Yes** |

---

## hreflang Implementation

hreflang tells Google: "This page is for [language/country], and here are the equivalent pages for other [language/country] combinations."

### Syntax

```html
<link rel="alternate" hreflang="LANGUAGE-COUNTRY" href="URL">
```

**Language code**: ISO 639-1 (2-letter: en, de, fr, ja, zh)
**Country code**: ISO 3166-1 alpha-2 (2-letter: US, GB, DE, FR, AU)

### Common hreflang Values

| Tag | Targets |
|-----|---------|
| `hreflang="en"` | All English speakers (no specific country) |
| `hreflang="en-US"` | English speakers in the United States |
| `hreflang="en-GB"` | English speakers in the United Kingdom |
| `hreflang="en-AU"` | English speakers in Australia |
| `hreflang="de"` | All German speakers |
| `hreflang="de-DE"` | German speakers in Germany |
| `hreflang="de-AT"` | German speakers in Austria |
| `hreflang="fr-FR"` | French speakers in France |
| `hreflang="fr-CA"` | French speakers in Canada |
| `hreflang="zh-Hans"` | Simplified Chinese |
| `hreflang="zh-Hant"` | Traditional Chinese |
| `hreflang="x-default"` | Default page (no specific language/country) |

### x-default: International Landing Page

Use `x-default` for your international gateway page (e.g., a language/country selector page, or your primary .com page that serves all non-targeted users).

```html
<link rel="alternate" hreflang="x-default" href="https://example.com/">
```

This tells Google: "If no better language/country match exists for this user, send them here."

### The Return Tag Requirement

**CRITICAL**: Every page in a hreflang group must include ALL tags in the set, including a self-referencing tag pointing to itself.

**Correct implementation** on the German page (`example.com/de/`):

```html
<!-- On example.com/de/ (German page) -->
<link rel="alternate" hreflang="de" href="https://example.com/de/">  <!-- Self-reference -->
<link rel="alternate" hreflang="en" href="https://example.com/">
<link rel="alternate" hreflang="en-US" href="https://example.com/us/">
<link rel="alternate" hreflang="fr" href="https://example.com/fr/">
<link rel="alternate" hreflang="x-default" href="https://example.com/">
```

**Common mistake**: Only adding hreflang on one page without reciprocal tags on the target pages. Google ignores one-sided hreflang.

### Implementation Methods

**Method 1: HTML `<head>` (most common)**

Place all hreflang `<link>` tags inside `<head>`. Suitable for most sites.

```html
<head>
  <link rel="alternate" hreflang="en" href="https://example.com/">
  <link rel="alternate" hreflang="de" href="https://example.com/de/">
  <link rel="alternate" hreflang="fr" href="https://example.com/fr/">
  <link rel="alternate" hreflang="x-default" href="https://example.com/">
</head>
```

**Method 2: XML Sitemap (preferred for large sites)**

Avoids bloating every page's HTML. One sitemap manages all hreflang declarations.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
  xmlns:xhtml="http://www.w3.org/1999/xhtml">
  <url>
    <loc>https://example.com/</loc>
    <xhtml:link rel="alternate" hreflang="en" href="https://example.com/"/>
    <xhtml:link rel="alternate" hreflang="de" href="https://example.com/de/"/>
    <xhtml:link rel="alternate" hreflang="fr" href="https://example.com/fr/"/>
    <xhtml:link rel="alternate" hreflang="x-default" href="https://example.com/"/>
  </url>
  <url>
    <loc>https://example.com/de/</loc>
    <xhtml:link rel="alternate" hreflang="en" href="https://example.com/"/>
    <xhtml:link rel="alternate" hreflang="de" href="https://example.com/de/"/>
    <xhtml:link rel="alternate" hreflang="fr" href="https://example.com/fr/"/>
    <xhtml:link rel="alternate" hreflang="x-default" href="https://example.com/"/>
  </url>
</urlset>
```

**Method 3: HTTP Header (for non-HTML files)**

For PDFs and other non-HTML resources:
```
Link: <https://example.com/de/guide.pdf>; rel="alternate"; hreflang="de"
```

### Common hreflang Errors

| Error | Symptom | Fix |
|-------|---------|-----|
| Missing return tag | Google ignores hreflang; wrong language shown | Add reciprocal tags on all alternate pages |
| Orphaned pages | A page in one language has no hreflang; gets treated as duplicate | Add to hreflang group |
| Wrong ISO codes | hreflang attribute unrecognized | Use ISO 639-1 (language) + ISO 3166-1 alpha-2 (country) |
| Pointing to non-indexable pages | hreflang references 404, noindex, or redirect URLs | Fix the target URL; hreflang must point to indexable content |
| Canonical + hreflang conflict | Canonical points away from the alternate URL | See Edge Cases section |
| Too many hreflang tags | Crawl overhead for very large sites | Use XML sitemap method instead of HTML |

### Testing Tools

- **Hreflang Tag Testing Tool** (Merkle, free): Validates hreflang syntax and return tags
- **Screaming Frog**: Crawls and validates all hreflang relationships at scale
- **Ahrefs Site Audit**: Flags hreflang errors in crawl report
- **Google Search Console**: International targeting report; coverage issues for hreflang

---

## Search Console Setup for International Sites

### Geo-Targeting Per Property

**For ccTLDs**: Google automatically geo-targets. No GSC action needed.

**For subdomains and subfolders**:
1. Add each subdomain/subfolder as a separate property in GSC
2. Go to Legacy Tools > International Targeting
3. Set target country for the property
4. GSC geo-targeting is a soft signal; hreflang is stronger

### Submitting International Sitemaps

- Submit separate sitemap per locale OR include all in one sitemap index
- Best practice: separate sitemap per locale for easier troubleshooting
  - sitemap-en.xml, sitemap-de.xml, sitemap-fr.xml
  - Reference all in sitemap-index.xml

### International Targeting Tool

GSC > Legacy Tools > International Targeting shows:
- Language targeting report (hreflang errors)
- Country targeting report (if set via GSC)

---

## Content Localization vs Translation

### Machine Translation Risks

Google has stated that using machine translation to create pages at scale, with no additional value-add, constitutes spam under their policies (March 2024 Spam Update). Sites doing this at scale have been penalized.

**Prohibited approach**: Auto-translating all pages via Google Translate or DeepL without human review.

**Acceptable approach**: Machine translation as a first draft, with human review, cultural adaptation, and quality check before publishing.

### Localization vs Translation

**Translation**: Converting text from one language to another (literal)
**Localization**: Adapting content for the target culture (date formats, currency, units of measure, idiomatic expressions, cultural references, local examples)

What localization requires:
- Currency in local format (€ vs $ vs £)
- Date formats (MM/DD/YYYY vs DD/MM/YYYY)
- Phone number formats (country code conventions)
- Local examples, case studies, testimonials
- Cultural adaptation of images (diverse representation, local context)
- Legal compliance (GDPR in EU, different consumer protection disclosures)

### Local Keyword Research

**Do not translate keywords.** German users searching for "Laufschuhe" are not using the German translation of "running shoes" — they're using the actual term German speakers use. Conduct native keyword research:

Process:
1. Use Ahrefs or Semrush in the target country + language setting
2. Start with translated term, then explore related terms in native language
3. Check Google Autocomplete and People Also Ask in the target region (use VPN or browser locale setting)
4. Consult native speakers for idiomatic search phrasing

### Regional Search Engines

| Country | Primary Search Engine | Notes |
|---------|----------------------|-------|
| China | Baidu (80%+ share) | Requires .cn domain or Chinese hosting; simplified Chinese; separate SEO rules |
| Russia | Yandex (50%+ share) | Yandex Webmaster Tools; Yandex Metrica analytics; requires ICP equivalent |
| South Korea | Naver (60%+ share) | Different algorithm; blog content (Naver Blog) heavily weighted |
| Japan | Yahoo Japan (30%+ share) | Powered by Google since 2010; optimize for Google |
| Czech Republic | Seznam (20% share) | Worth submitting to Seznam Fulltext |

For Baidu:
- Simplified Chinese content required
- Hosting in mainland China or Hong Kong for speed
- ICP license required for .cn domains
- Baidu Webmaster Tools (equivalent to GSC)
- Baidu prefers frequent content updates

---

## International Link Building

### Regional Link Profile

A site's authority in a given country is partly determined by local backlinks:
- Links from .de domains help rank in Germany
- Links from German news sites, directories, trade publications signal local relevance
- Reciprocal hreflang relationship means both language versions benefit from each other's links

### Local Directory Submissions

By country:
- **Germany**: Das Örtliche, Gelbe Seiten, Yelp.de, Foursquare.de
- **UK**: Yell.com, Thomson Local, Bing Places UK, FreeIndex
- **France**: PagesJaunes, Yelp.fr
- **Spain**: Páginas Amarillas, Yelp.es
- **Italy**: PagineGialle, Yelp.it

### Country-Specific PR

For significant markets:
- Press releases in local language to local wire services
- Build relationships with local trade journalists
- Contribute to local industry associations/publications
- Sponsor local events (gets local mentions and links)

---

## Edge Cases

### Canonical + hreflang Conflict

**Problem**: If page A canonicals to page B, but page A is listed in a hreflang group, Google may ignore the hreflang for page A.

**Rule**: Every page in a hreflang group must have a self-referencing canonical (canonical = its own URL). Never canonical an hreflang page to another URL.

Correct:
```html
<!-- On example.com/de/ -->
<link rel="canonical" href="https://example.com/de/">  <!-- Self-referencing -->
<link rel="alternate" hreflang="de" href="https://example.com/de/">
```

Wrong:
```html
<!-- On example.com/de/ -->
<link rel="canonical" href="https://example.com/">  <!-- Points to English version -->
<!-- Google will likely ignore the hreflang for this page -->
```

### Migrating to hreflang from Single-Language Site

1. Create new language versions (subfolders recommended)
2. Fully translate and localize before launch
3. Add hreflang to ALL pages simultaneously (incomplete implementation confuses Google)
4. Submit updated sitemap to GSC immediately
5. Monitor GSC International Targeting report for errors over first 4-6 weeks
6. Expect 4-8 weeks before Google fully processes hreflang signals

---

## Common Mistakes

- **Translating keywords instead of researching native terms**: Results in targeting phrases real users don't search
- **Missing return tags**: Single most common hreflang error; causes Google to ignore the entire implementation
- **Machine translation at scale without review**: Google spam policy violation since 2024
- **Geo-targeting via GSC only, skipping hreflang**: GSC targeting is weaker signal; both should be used together
- **Incorrectly using hreflang="en" when you mean "en-US"**: "en" targets all English speakers globally; if content is US-specific, use "en-US"
- **Not checking if regional search engines require separate optimization**: Baidu, Yandex, and Naver have different algorithms
- **Launching hreflang incrementally**: Implement across all pages simultaneously; partial hreflang confuses crawlers
