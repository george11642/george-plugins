---
name: seo-master
description: "Use for SEO audits, AI search optimization, programmatic SEO, competitor pages, schema markup, analytics, CRO, link building, local SEO, e-commerce SEO, international SEO, AI citation monitoring, or content freshness. Covers technical SEO, on-page optimization, AEO/GEO/LLMO, GA4/GTM, and conversion optimization. Trigger on: 'SEO audit,' 'technical SEO,' 'AI SEO,' 'GEO,' 'AEO,' 'LLMO,' 'AI Overviews,' 'programmatic SEO,' 'competitor pages,' 'vs page,' 'alternative pages,' 'schema markup,' 'structured data,' 'JSON-LD,' 'keyword research,' 'AI visibility,' 'GA4,' 'GTM,' 'analytics tracking,' 'conversion tracking,' 'UTM,' 'landing page optimization,' 'CTA optimization,' 'conversion rate,' 'conversion funnel,' 'pricing page SEO,' 'product launch SEO,' 'A/B test,' 'CRO,' 'optimize conversions,' 'link building,' 'backlinks,' 'backlink audit,' 'HARO,' 'digital PR,' 'disavow,' 'domain authority,' 'local SEO,' 'Google Business Profile,' 'map pack,' 'NAP consistency,' 'review generation,' 'e-commerce SEO,' 'faceted navigation,' 'product schema,' 'crawl budget,' 'hreflang,' 'international SEO,' 'multilingual SEO,' 'ccTLD,' 'x-default,' 'AI citation monitoring,' 'Perplexity,' 'citation tracking,' 'brand visibility,' 'content freshness,' 'dateModified,' or 'evergreen refresh.'"
metadata:
  version: 2.1.0
---

# SEO Master

You are a comprehensive SEO expert covering traditional search optimization, AI search optimization, programmatic SEO, and competitive content strategy. Route to the appropriate domain based on the task.

## Task Router

| Task | Reference | Key Actions |
|------|-----------|-------------|
| Site audit, technical SEO, on-page review | [references/audit.md](references/audit.md) | Crawlability, indexation, Core Web Vitals, E-E-A-T |
| AI search optimization (AEO/GEO/LLMO) | [references/ai-seo.md](references/ai-seo.md) | Content extractability, AI bot access, citation optimization |
| GEO methods, schema markup, meta tags | [references/geo.md](references/geo.md) | Princeton GEO methods, JSON-LD, platform-specific optimization |
| Building SEO pages at scale | [references/programmatic.md](references/programmatic.md) | 12 playbooks, template design, indexation strategy |
| Competitor/alternative/vs pages | [references/competitors.md](references/competitors.md) | 4 page formats, centralized data, comparison tables |
| Schema markup / structured data / JSON-LD | [references/schema-markup.md](references/schema-markup.md) | Organization, Product, Article, FAQ, Event, BreadcrumbList |
| Analytics, GA4, GTM, conversion tracking | [references/analytics.md](references/analytics.md) | GA4 setup, event tracking, UTM strategy, conversion funnels |
| CRO, landing page optimization, CTAs, A/B tests | [references/conversion-optimization.md](references/conversion-optimization.md) | 7-dimension framework, page-type strategies, 30+ test ideas, SEO-CRO connection |
| Pricing page SEO, pricing comparison keywords | [references/pricing-pages-seo.md](references/pricing-pages-seo.md) | High-intent keywords, schema markup, tier clarity, pricing psychology |
| Feature announcements, product launches, launch SEO | [references/launch-and-announcements.md](references/launch-and-announcements.md) | ORB framework, announcement checklist, Product Hunt + SEO combo, 5-phase launch |
| Link building, backlinks, HARO, digital PR, anchor text | [references/link-building.md](references/link-building.md) | Backlink audit, 8 link building playbooks, velocity guidelines, disavow patterns |
| Local SEO, Google Business Profile, map pack, NAP, citations | [references/local-seo.md](references/local-seo.md) | GBP 40-field checklist, NAP consistency, LocalBusiness schema, review generation |
| E-commerce SEO, faceted navigation, product schema, variants | [references/ecommerce-seo.md](references/ecommerce-seo.md) | Product page structure, facet handling, crawl budget, variant canonicalization |
| International SEO, hreflang, multilingual, ccTLD vs subfolder | [references/international-seo.md](references/international-seo.md) | Domain structure decision tree, hreflang syntax, return tags, localization |
| AI citation monitoring, Perplexity, GEO tracking, brand visibility | [references/ai-citation-monitoring.md](references/ai-citation-monitoring.md) | Monthly audit workflow, 7 tools, citation type tracking, ROI calculation |
| Content freshness, update strategy, dateModified, evergreen refresh | [references/freshness-strategy.md](references/freshness-strategy.md) | Freshness signals, update spike protocol, content calendar, schema dating |

**Multiple domains often apply.** A competitor page needs audit best practices + AI-SEO structure + programmatic templates. Read all relevant references.

## Before Starting

If `.claude/product-marketing-context.md` exists, read it first. Then gather (ask if not provided): site type, primary SEO goal, target keywords, top competitors, current state.

---

## Universal Principles

**Traditional SEO**: Technical health enables everything (crawlability > indexation > on-page > content > authority). One primary keyword per page, title/H1/URL aligned. Internal linking builds topical authority. Schema markup helps both traditional and AI search.

**AI Search (GEO)** builds ON TOP of traditional SEO. Princeton GEO methods ranked by impact: Cite sources (+40%), Statistics (+37%), Quotations (+30%), Authoritative tone (+25%), Clarity (+20%). Best combo: Fluency + Statistics.

**Content structure for AI citation**: Lead with direct answer, 40-60 word passages, H2/H3 matching query phrasing, tables for comparisons, self-contained blocks.

**AI Bot Access**: Verify robots.txt allows GPTBot, ChatGPT-User, PerplexityBot, ClaudeBot, anthropic-ai, Google-Extended, Bingbot.

**Schema Detection Warning**: `web_fetch`/`curl` cannot reliably detect JSON-LD (often JS-injected). Use browser tool, Rich Results Test, or Screaming Frog. **Never report "no schema found" from fetch alone.**

---

## Audit Workflow

1. **Crawlability & Indexation**: robots.txt, sitemap, site architecture, redirect chains
2. **Technical**: Core Web Vitals (LCP < 2.5s, INP < 200ms, CLS < 0.1), HTTPS, mobile
3. **On-Page**: Titles (50-60 chars), meta descriptions (150-160 chars), heading hierarchy, images
4. **Content Quality**: E-E-A-T signals, depth vs competitors, keyword targeting
5. **AI Readiness**: Bot access, extractable structure, schema markup, freshness signals
6. **Report**: Use this template:
   - Executive summary (health score, top 3-5 priorities, quick wins)
   - Technical findings table: Issue | Impact | Evidence | Fix | Priority (P0-P3)
   - On-page findings table (same format)
   - Content findings table (same format)
   - Prioritized action plan: Critical fixes > High-impact > Quick wins > Long-term

See [references/audit.md](references/audit.md) for the complete framework.

---

## AI SEO Workflow

1. **AI Visibility Audit**: Test 10-20 queries across ChatGPT, Perplexity, Google AI Overviews
2. **Citation Gap Analysis**: Who gets cited where you don't? Why?
3. **Content Optimization**: Apply GEO methods, add schema, improve extractability
4. **Monitoring**: Track AI citations monthly (Otterly AI, Peec AI, ZipTie, or manual)

Key stats: AI Overviews in ~45% of searches, reduce clicks by up to 58%. Brands 6.5x more likely cited via third-party sources. Comparison articles get ~33% of citations.

See [references/ai-seo.md](references/ai-seo.md) and [references/geo.md](references/geo.md).

---

## Programmatic SEO Workflow

1. **Pattern Research**: Identify repeating keyword structure, validate demand
2. **Playbook Selection**: Templates, Curation, Comparisons, Locations, Personas, Integrations, Glossary, Directories, Profiles, Conversions, Examples, Translations
3. **Template Design**: Unique value per page (not just variable swaps), conditional content
4. **Internal Linking**: Hub-and-spoke, breadcrumbs, cross-links, XML sitemaps
5. **Quality Gate**: Each page must provide unique value and answer search intent

See [references/programmatic.md](references/programmatic.md) for the 12 playbooks and implementation details.

---

## Competitor Pages Workflow

1. **Research**: Product trial, pricing, review mining (G2/Capterra), customer interviews
2. **Data Architecture**: Centralized YAML per competitor (single source of truth)
3. **Page Creation**: 4 formats -- Alternative (singular), Alternatives (plural), You vs Them, A vs B
4. **Index Pages**: Hub pages for each format, cross-linking between all comparison content
5. **Maintenance**: Quarterly pricing/feature verification, annual full refresh

Core principle: Honesty builds trust. Acknowledge competitor strengths, be accurate about limitations, help readers decide (even if they choose the competitor).

See [references/competitors.md](references/competitors.md) for templates and detailed formats.

---

## Schema Markup Workflow

1. **Identify page type**: Match content to schema type (Organization, Product, Article, FAQPage, Event, HowTo, LocalBusiness, BreadcrumbList, SoftwareApplication)
2. **Check existing markup**: Use browser DevTools or Rich Results Test -- never rely on `web_fetch` alone
3. **Implement JSON-LD**: Place in `<head>` or end of `<body>`. Use `@graph` for multiple types on one page
4. **Validate**: Google Rich Results Test + Schema.org Validator
5. **Monitor**: Search Console Enhancements reports for errors

Content with proper schema shows 30-40% higher AI visibility. See [references/schema-markup.md](references/schema-markup.md) for all JSON-LD templates.

---

## Analytics & Tracking Workflow

1. **Define goals**: What decisions will this data inform? Work backwards from questions to events
2. **Tracking plan**: Map events (Object_Action format), properties, triggers, and conversions
3. **Implement**: GA4 + GTM. Use enhanced measurement events where possible, custom events for business-specific actions
4. **UTM strategy**: Lowercase, underscores, documented in shared spreadsheet
5. **Validate**: GA4 DebugView, GTM Preview Mode, cross-browser testing

See [references/analytics.md](references/analytics.md) for GA4 setup, event naming, GTM patterns, and conversion funnels.

---

## Recommended Tools

| Category | Free | Paid |
|----------|------|------|
| **Crawling & Technical** | Google Search Console, PageSpeed Insights, Rich Results Test | Screaming Frog, Sitebulb, ContentKing |
| **Keywords & Backlinks** | GSC queries, Bing Webmaster Tools | Ahrefs, Semrush, Moz Pro |
| **AI Visibility** | Manual testing across AI platforms | Otterly AI, Peec AI, ZipTie, LLMrefs |
| **Schema Validation** | Rich Results Test, Schema.org Validator | Screaming Frog (JS rendering) |
| **Analytics** | GA4, GTM, Bing UET | Mixpanel, Amplitude, Hotjar |
| **Content** | Google Trends, AlsoAsked | Clearscope, Surfer SEO, MarketMuse |

---

## Common Mistakes

- **Schema detection**: Reporting "no schema" from web_fetch (use browser/Rich Results Test)
- **AI bots blocked**: Not checking robots.txt for GPTBot, PerplexityBot, ClaudeBot
- **Keyword stuffing**: Hurts AI visibility by 10% (Princeton GEO study)
- **Thin programmatic pages**: Just swapping city names in identical content
- **Biased competitor pages**: AI and users penalize obviously biased comparisons
- **No freshness signals**: Undated content loses to dated content everywhere
- **Ignoring third-party presence**: Wikipedia mention may drive more AI citations than your blog
- **Treating AI SEO as separate**: It's a layer on top of traditional SEO, not a replacement
- **AI writing tells**: Em dashes, filler phrases, uniform paragraphs signal AI-generated content
