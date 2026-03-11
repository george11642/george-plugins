# E-Commerce SEO Reference

## Overview

E-commerce SEO has unique challenges: thousands of product pages, faceted navigation creating URL explosion, duplicate manufacturer content, variant canonicalization, and crawl budget constraints. The 2025 landscape adds AI Overviews pulling product data from schema markup directly. Getting Product schema right now serves both Google Shopping and AI-generated shopping recommendations.

---

## Product Page Structure

### Title Tag Formula

```
[Product Name] - [Key Differentiating Attribute] | [Brand Name]
```

Examples:
- "Men's Running Shoes - Lightweight Mesh, Size 7-15 | Nike"
- "iPhone 15 Pro Case - Magsafe Compatible, Drop Protection | Spigen"
- "Organic Green Tea - 100 Bags, Ceremonial Grade | Harney & Sons"

**Rules**:
- 50-60 characters maximum
- Most important attributes first
- Brand in title only if brand recognition adds value
- Avoid filler words ("buy", "cheap", "best") in title tag — they dilute keyword signal
- No ALL CAPS

### H1 vs Title Tag Relationship

- H1 and title tag should target the same primary keyword
- H1 can be slightly longer and more conversational
- H1 is the most prominent on-page signal for keyword relevance
- Never have multiple H1s on a product page

Example:
- Title: "Men's Running Shoes - Lightweight Mesh | Nike"
- H1: "Nike Men's Lightweight Running Shoes"

### Product Description Uniqueness

**Critical**: Using manufacturer-provided copy verbatim means your product page is a duplicate of every other retailer using the same copy. Google will rank the original source over copies.

**Approach for unique descriptions**:
1. Use manufacturer copy as baseline only
2. Rewrite with different sentence structure and vocabulary
3. Add unique angles: how customers actually use it, comparison to previous model, specific use case scenarios
4. Include user-generated content angles (common questions from reviews)
5. For high-volume SKUs: full custom description (300-500 words)
6. For long-tail/low-volume SKUs: semi-custom template with meaningful variable content

**Minimum viable unique content**:
- 100+ words unique to this page
- 1-2 unique product angles not in manufacturer copy
- Integrate primary keyword + 2-3 semantic variants naturally

### Image Optimization

| Element | Best Practice |
|---------|--------------|
| Alt text | Descriptive: "[Brand] [Product Name] [Color/Size] - [Key Feature]". Not keyword-stuffed. |
| Filename | descriptive-product-name-color.webp (hyphens, no spaces, lowercase) |
| Format | WebP primary, JPEG fallback (PNG only for transparency) |
| Size | Product main image: 800x800px minimum; zoom-capable: 1200x1200px |
| Count | 5-8 images: front, back, sides, in-use, detail shots |
| Compression | Target < 150KB per image with WebP |

### Reviews Integration

Reviews improve:
- Conversion rate (primary purpose)
- Average dwell time on product pages
- Long-tail keyword coverage (customers use different vocabulary)
- AI visibility (aggregateRating schema triggers rich snippet + AI Overview data)

**Schema integration**: See AggregateRating section in schema-markup.md. Product + AggregateRating combined enables star ratings in SERPs.

### Internal Linking on Product Pages

**Breadcrumbs** (required):
- Home > Category > Subcategory > Product
- Implement BreadcrumbList schema alongside visual breadcrumbs
- Link every level in the breadcrumb trail

**Related products section**:
- "Frequently bought together" (basket analysis data)
- "Similar products" (same category, different specs)
- "Recently viewed" (personalization, reduces bounce)

**Cross-sell links**:
- Accessories that complement the product
- Upsell to premium version

**Content links**:
- "How to use" guide
- "Buying guide for [product category]"

### Canonical for Variant Handling

See Variant Handling section below.

---

## Category / Collection Pages

Category pages often rank for high-volume, broad keywords. They deserve as much SEO attention as product pages.

### Unique Content Requirements

Google has explicitly stated that thin category pages with only product grids provide little value. Category pages need:

- Minimum 200 words of unique introductory text
- Text placed above the fold (before product grid) OR at bottom (A/B test which works better for UX)
- Must genuinely describe the category: what types of products, how to choose, key features to look for
- Include primary keyword + semantic variants
- Link to buying guide content (builds topical authority)

**Category text template**:
```
[H1: Category Name]
[Paragraph 1: What this category is, who it's for, 2-3 sentences]
[Paragraph 2: Key considerations when choosing — attributes, specs to evaluate]
[Paragraph 3: Top picks or featured brands, with keyword mentions]
[Product Grid]
[Optional footer text: broader context, history, FAQ]
```

### H1 with Primary Keyword

H1 should match the category's primary search query:
- Research category page: "Running Shoes" vs "Men's Running Shoes" vs "Best Running Shoes"
- GSC query data shows what users actually search to reach the category
- H1 = most searched variant; title tag can differ slightly

### Facet URL Handling

See dedicated Faceted Navigation section below.

### Pagination

Two valid approaches in 2025:

**Option A: Individual page indexing** (recommended for deep catalogs)
- Each page (/category/page/2, /category/page/3) is indexed
- Add unique text per page: "Page 2 of Running Shoes — showing items 25-48"
- Include canonical pointing to the individual page (self-referencing canonical)
- Use rel=prev/next (still works as a hint, though Google dropped official support)

**Option B: Canonical to first page** (simpler, for shallow catalogs)
- All paginated pages canonical to page 1
- Risk: deep products on page 10+ may never rank

**What to avoid**: Noindexing all paginated pages (products on later pages get no organic discoverability).

---

## Faceted Navigation (Critical)

Faceted navigation (filters by color, size, brand, price, rating) is the biggest crawl budget and duplicate content threat for large e-commerce sites.

### The Problem at Scale

A site with:
- 10,000 products
- Filters: color (10 options) x size (8) x brand (20) x price range (5) = 8,000 potential filter combinations

= Up to 80 million possible URLs. Googlebot crawls this endlessly, never reaching your actual product pages.

### Decision Framework: Index or Block?

**Noindex + nofollow (default for most facets)**:
Use when the filter combination:
- Creates few or no unique results
- Has negligible search volume for the filtered query
- Produces near-duplicate content

```html
<!-- In <head> of faceted URL -->
<meta name="robots" content="noindex, nofollow">
```

**Allow indexing (selective)**:
Use when the filter combination:
- Has measurable search volume (verify in GSC + Ahrefs)
- Creates meaningfully unique content (specific brand+category combos)
- Represents a real user segment ("red running shoes women size 8" gets ~2,400/mo)

Examples of indexable facets:
- `/womens-running-shoes/color/red/` — if "red women's running shoes" has real volume
- `/laptops/brand/apple/` — "Apple laptops" is a valid search query
- `/dresses/occasion/wedding/` — "wedding dresses" is a separate high-value category

**URL parameter exclusion in GSC** (simpler alternative to noindex):
- GSC > Legacy Tools > URL Parameters
- Specify parameters that don't change content (session IDs, tracking params)
- Not available for all parameter types

### Implementation Patterns

**Pattern 1: Canonical URL consolidation** (recommended)
```html
<!-- On /shoes?color=red&size=8 -->
<link rel="canonical" href="https://example.com/shoes/">
<!-- Points all variants to the clean category URL -->
```

**Pattern 2: Noindex + nofollow on generated facet pages**
```html
<meta name="robots" content="noindex, nofollow">
<!-- Use when: facet has no real search demand, but users need it for UX -->
```

**Pattern 3: AJAX/JavaScript filtering (no URL change)**
- Filter changes happen client-side without URL changes
- Googlebot only sees the base category page
- Risk: users can't share/bookmark filtered results
- Hybrid: allow URL update via `history.pushState()` but implement canonical to base page

**Pattern 4: URL parameter exclusion**
- Configure in GSC URL Parameters (crawl budget protection)
- Less precise than canonical/noindex

### Crawl Budget Protection

Priority for large e-commerce sites:
1. Disallow faceted URLs in robots.txt if they're never indexable:
   ```
   Disallow: /*?color=
   Disallow: /*?size=
   ```
2. Remove facet URLs from XML sitemap (never include noindex pages)
3. Avoid linking to faceted URLs from main navigation or internal links
4. Monitor crawl stats in GSC (Coverage > Crawl Stats) for anomalies

### JavaScript-Rendered Facets vs Server-Side

| Approach | SEO Behavior | Notes |
|----------|-------------|-------|
| Server-side rendering (full page load) | Googlebot sees new URL, follows/indexes per signals | Traditional approach; full crawl budget impact |
| Client-side JS, URL change via pushState | Googlebot may or may not follow/render | Slower indexing; canonical to base URL recommended |
| Client-side JS, no URL change | Googlebot only sees base page | Good for crawl budget; bad for deep product discoverability |
| Hybrid (SSR for first load, JS for subsequent) | Best of both worlds | Most complex; required for large crawl budget sites |

---

## Variant Handling

### The Core Question

When a product has variants (color, size, material): separate URLs or canonical?

**Option A: All variants → canonical to parent**
```html
<!-- On /shoes/running-shoe-blue/ and /shoes/running-shoe-red/ -->
<link rel="canonical" href="https://example.com/shoes/running-shoe/">
```
Use when: variants are essentially the same product; no unique search demand per variant; variant pages are thin.

**Option B: Individual variant URLs with unique content**
Use when:
- Specific variant has own search demand (e.g., "red Nike Air Max" has search volume)
- Each variant page has substantially unique content, images, and description
- The variant is a genuinely different product (not just color swap)

**Hybrid approach (recommended)**:
- Parent product page: canonical to itself; richest content, all variants listed
- Color/size variants: canonical to parent unless they have own search demand
- Exception: if a specific variant (size, color, material) has >500 searches/month, give it a standalone indexed URL with unique content

### Out-of-Stock Products

**Keep indexed if**:
- Product will return to stock within 3-6 months
- URL has backlinks or organic traffic
- It's a popular/searched-for item

**Implementation when out of stock**:
- Update Product schema: `"availability": "https://schema.org/OutOfStock"`
- Display clear "out of stock" message with expected restock date if known
- Offer "notify me" email capture
- Show similar in-stock alternatives (internal linking opportunity)

**Redirect if**:
- Product is permanently discontinued
- 301 redirect to: parent category > most similar in-stock product > homepage (in that priority)
- Don't 404 a page with backlinks — always redirect

### SKU Canonicalization Patterns

For sites where same product appears under multiple URLs due to CMS behavior:
```
/product/blue-shoes-SKU123
/category/running/blue-shoes-SKU123
/search?q=SKU123 (should be noindexed)
```

Set canonical on all variant URLs to the primary URL. The primary URL should be the most semantically clean, keyword-rich URL.

---

## Rich Snippets: Product Schema

### Complete Product + AggregateRating JSON-LD

```json
{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": "Nike Air Max 270 - Men's Running Shoe",
  "image": [
    "https://example.com/images/air-max-270-front.jpg",
    "https://example.com/images/air-max-270-side.jpg",
    "https://example.com/images/air-max-270-sole.jpg"
  ],
  "description": "The Nike Air Max 270 features a full-length Air unit for maximum cushioning. Lightweight mesh upper for breathability.",
  "sku": "AM270-M-BLK-10",
  "mpn": "AH8050-002",
  "brand": {
    "@type": "Brand",
    "name": "Nike"
  },
  "offers": {
    "@type": "Offer",
    "url": "https://example.com/products/nike-air-max-270-mens",
    "priceCurrency": "USD",
    "price": "150.00",
    "priceValidUntil": "2025-12-31",
    "itemCondition": "https://schema.org/NewCondition",
    "availability": "https://schema.org/InStock",
    "seller": {
      "@type": "Organization",
      "name": "Your Store Name"
    }
  },
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": "4.6",
    "reviewCount": "1847",
    "bestRating": "5",
    "worstRating": "1"
  },
  "review": [
    {
      "@type": "Review",
      "reviewRating": {
        "@type": "Rating",
        "ratingValue": "5",
        "bestRating": "5"
      },
      "name": "Best running shoe I've owned",
      "author": {
        "@type": "Person",
        "name": "John D."
      },
      "datePublished": "2024-11-15"
    }
  ]
}
```

**Required for Google rich results**: name, image, offers (price + availability + condition)
**Strongly recommended**: aggregateRating (enables star display in SERPs), brand, sku

### Triggering Rich Snippets

Rich snippets appear when:
1. Schema is valid (test with Rich Results Test)
2. Page has sufficient authority and trust
3. Content matches the schema (Google cross-checks)
4. Review count is meaningful (1+ reviews required; 5+ for display)

What you'll see:
- Star ratings under result in SERPs (from AggregateRating)
- Price and availability (from Offers)
- Product carousels in AI Overviews and Shopping tab

---

## Crawl Budget

Critical for sites with 10,000+ pages.

### XML Sitemaps

- **Include**: All indexable product pages, category pages, canonical versions
- **Exclude**: Noindex pages, faceted URLs, paginated pages (unless individually indexed strategy), out-of-stock pages (optional — include if temporarily OOS)
- Split large sitemaps: max 50,000 URLs or 50MB per sitemap file
- Use sitemap index file to reference multiple sitemaps
- Submit to Google Search Console; monitor for errors

### Internal Linking to Prioritize Crawl

- Every product/category page should be reachable within 3 clicks from homepage
- Products with highest revenue/margin → highest internal link equity
- Seasonal products: increase internal links before peak season
- Orphan pages (0 internal links) get minimal crawl frequency

### Page Speed as Crawl Rate Factor

Google reduces crawl rate for slow sites. For e-commerce:
- LCP < 2.5s (product pages, especially mobile)
- Core Web Vitals failures directly impact crawl rate
- Large product image carousels are common LCP culprits
- Lazy load below-fold images; eager load above-fold hero image

Crawl budget tools:
- GSC Coverage report + Crawl stats
- Screaming Frog (identify non-indexable pages eating budget)
- Botify (enterprise crawl budget analysis)
- Log file analysis (see what Googlebot actually crawls)

---

## Common E-Commerce SEO Mistakes

- **Thin category pages**: Product grid only, no descriptive content
- **Manufacturer description copy-paste**: Identical content across all retailers
- **Faceted navigation indexing**: All filter combinations indexed, bloating the index
- **Wrong canonical direction**: Variant pages canonical to parent, but parent canonical to a variant
- **404ing discontinued products**: Losing backlink equity; should 301 redirect
- **No AggregateRating schema**: Missing the rich snippet opportunity
- **Pagination noindexed entirely**: Deep products never discovered organically
- **Single product image**: Poor user experience + missed alt text keyword opportunities
- **No breadcrumbs**: Users and crawlers lose context; missing BreadcrumbList schema
- **Ignoring crawl budget**: 80% of Googlebot time spent on filter URLs, not product pages
