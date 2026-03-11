---
name: seo-growth
description: "Use for SEO audits, keyword research, schema markup, conversion optimization, and AI search visibility. Triggers on SEO, technical SEO, SEO audit, keyword research, schema markup, JSON-LD, structured data, meta tags, robots.txt, sitemap, Core Web Vitals, GA4, GTM, conversion tracking, CRO, landing page optimization, A/B test, AI SEO, GEO, AEO, LLMO, programmatic SEO, competitor pages, link building, backlinks, local SEO, Google Business Profile, e-commerce SEO, hreflang, international SEO, AI citation, GPTBot, PerplexityBot, ClaudeBot, content freshness, pricing page SEO, product launch SEO."
metadata:
  version: 1.0.0
---

# SEO & Growth

Route SEO, growth, and AI search optimization tasks to the correct reference. Read all relevant references before starting — most tasks span multiple domains.

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
| CRO, landing page optimization, CTAs, A/B tests | [references/conversion-optimization.md](references/conversion-optimization.md) | 7-dimension framework, page-type strategies, 30+ test ideas |
| Pricing page SEO, pricing comparison keywords | [references/pricing-pages-seo.md](references/pricing-pages-seo.md) | High-intent keywords, schema markup, pricing psychology |
| Feature announcements, product launch SEO | [references/launch-and-announcements.md](references/launch-and-announcements.md) | ORB framework, announcement checklist, 5-phase launch |
| Link building, backlinks, HARO, digital PR | [references/link-building.md](references/link-building.md) | Backlink audit, 8 playbooks, velocity guidelines, disavow |
| Local SEO, Google Business Profile, map pack | [references/local-seo.md](references/local-seo.md) | GBP 40-field checklist, NAP consistency, LocalBusiness schema |
| E-commerce SEO, faceted navigation, product schema | [references/ecommerce-seo.md](references/ecommerce-seo.md) | Product page structure, facet handling, crawl budget |
| International SEO, hreflang, multilingual | [references/international-seo.md](references/international-seo.md) | Domain structure decision tree, hreflang syntax, localization |
| AI citation monitoring, Perplexity, GEO tracking | [references/ai-citation-monitoring.md](references/ai-citation-monitoring.md) | Monthly audit workflow, 7 tools, citation type tracking |
| Content freshness, update strategy, evergreen refresh | [references/freshness-strategy.md](references/freshness-strategy.md) | Freshness signals, update spike protocol, content calendar |

## Universal Principles

- **Traditional SEO**: Technical health enables everything (crawlability > indexation > on-page > content > authority). One primary keyword per page, title/H1/URL aligned.
- **AI Search (GEO)** builds on top of traditional SEO. Princeton GEO methods by impact: Cite sources (+40%), Statistics (+37%), Quotations (+30%), Authoritative tone (+25%), Clarity (+20%).
- **Content for AI citation**: Lead with direct answer, 40-60 word passages, H2/H3 matching query phrasing, tables for comparisons, self-contained blocks.
- **AI Bot Access**: Verify robots.txt allows GPTBot, ChatGPT-User, PerplexityBot, ClaudeBot, anthropic-ai, Google-Extended, Bingbot.
- **Schema Detection Warning**: `web_fetch`/`curl` cannot reliably detect JSON-LD (often JS-injected). Use browser tool, Rich Results Test, or Screaming Frog.

## Before Starting

If `.claude/product-marketing-context.md` exists, read it first. Then gather: site type, primary SEO goal, target keywords, top competitors, current state.

## Common Mistakes

- Reporting "no schema" from web_fetch (use browser/Rich Results Test)
- Not checking robots.txt for AI bots (GPTBot, PerplexityBot, ClaudeBot)
- Keyword stuffing (hurts AI visibility by 10%)
- Thin programmatic pages (just variable swaps in identical content)
- Biased competitor pages (AI and users penalize obvious bias)
- Treating AI SEO as separate from traditional SEO (it's a layer on top)

## Layer 3 Skills

- **analytics-posthog** — PostHog analytics, event tracking, conversion funnels
- **browser-agent** — Browser automation for SEO audits and testing
