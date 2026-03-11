# AI SEO Reference

## How AI Search Works

| Platform | How It Works | Source Selection |
|----------|-------------|----------------|
| **Google AI Overviews** | Summarizes top-ranking pages | Strong correlation with traditional rankings |
| **ChatGPT (with search)** | Searches web, cites sources | Wider range, not just top-ranked |
| **Perplexity** | Always cites sources with links | Favors authoritative, recent, well-structured |
| **Gemini** | Google's AI assistant | Google index + Knowledge Graph |
| **Copilot** | Bing-powered AI search | Bing index + authoritative sources |
| **Claude** | Brave Search (when enabled) | Training data + Brave search results |

**Key difference**: Traditional SEO gets you ranked. AI SEO gets you **cited**. A well-structured page can get cited even from page 2-3.

**Critical stats:**
- AI Overviews appear in ~45% of Google searches
- AI Overviews reduce clicks by up to 58%
- Brands 6.5x more likely to be cited via third-party sources
- Optimized content gets cited 3x more often
- Statistics and citations boost visibility by 40%+

---

## AI Visibility Audit

### Check AI Answers for Key Queries
Test 10-20 important queries across ChatGPT, Perplexity, Google AI Overviews.

**Query types to test:**
- "What is [your product category]?"
- "Best [product category] for [use case]"
- "[Your brand] vs [competitor]"
- "How to [problem your product solves]"

### Content Extractability Check
- Clear definition in first paragraph
- Self-contained answer blocks
- Statistics with sources cited
- Comparison tables for "[X] vs [Y]" queries
- FAQ section with natural-language questions
- Schema markup (FAQ, HowTo, Article, Product)
- Expert attribution (author name, credentials)
- Recently updated (within 6 months)
- AI bots allowed in robots.txt

### AI Bot Access
Must allow in robots.txt:
- **GPTBot** and **ChatGPT-User** (OpenAI)
- **PerplexityBot** (Perplexity)
- **ClaudeBot** and **anthropic-ai** (Anthropic)
- **Google-Extended** (Gemini / AI Overviews)
- **Bingbot** (Copilot)

---

## Three Pillars of AI SEO

### Pillar 1: Structure (Make It Extractable)
- **Definition blocks** for "What is X?" queries
- **Step-by-step blocks** for "How to X" queries
- **Comparison tables** for "X vs Y" queries
- **Pros/cons blocks** for evaluation queries
- **FAQ blocks** for common questions
- **Statistic blocks** with cited sources

Rules: Lead with direct answer, keep passages 40-60 words, headings match query patterns, tables beat prose for comparisons.

### Pillar 2: Authority (Make It Citable)
Princeton GEO research (KDD 2024): Citations +40%, Statistics +37%, Quotations +30%, Authoritative tone +25%.

- Include specific numbers with original sources and dates
- Named authors with credentials, expert quotes with titles
- "Last updated" date prominently displayed
- Quarterly refreshes for competitive topics
- E-E-A-T alignment throughout

### Pillar 3: Presence (Be Where AI Looks)
Third-party sources matter more than your own site:
- Wikipedia mentions (7.8% of ChatGPT citations)
- Reddit discussions (1.8%)
- Industry publications, guest posts
- Review sites (G2, Capterra, TrustRadius)
- YouTube (frequently cited by Google AI Overviews)
- Quora answers

---

## Content Types That Get Cited Most

| Content Type | Citation Share | Why |
|-------------|:------------:|-----|
| Comparison articles | ~33% | Structured, balanced, high-intent |
| Definitive guides | ~15% | Comprehensive, authoritative |
| Original research/data | ~12% | Unique, citable statistics |
| Best-of/listicles | ~10% | Clear structure, entity-rich |
| Product pages | ~10% | Specific extractable details |
| How-to guides | ~8% | Step-by-step structure |

**Underperformers**: Generic blogs, thin product pages, gated content, undated content, PDF-only.

---

## Schema Markup for AI

| Content Type | Schema | Why It Helps |
|-------------|--------|-------------|
| Articles | `Article`, `BlogPosting` | Author, date, topic ID |
| How-to | `HowTo` | Step extraction |
| FAQs | `FAQPage` | Direct Q&A extraction |
| Products | `Product` | Pricing, features, reviews |
| Comparisons | `ItemList` | Structured comparison |
| Reviews | `Review`, `AggregateRating` | Trust signals |
| Organization | `Organization` | Entity recognition |

Content with proper schema shows 30-40% higher AI visibility.

---

## Monitoring AI Visibility

| Tool | Coverage | Best For |
|------|----------|----------|
| **Otterly AI** | ChatGPT, Perplexity, AI Overviews | Share of AI voice |
| **Peec AI** | ChatGPT, Gemini, Perplexity, Claude, Copilot+ | Multi-platform at scale |
| **ZipTie** | AI Overviews, ChatGPT, Perplexity | Brand mention + sentiment |
| **LLMrefs** | ChatGPT, Perplexity, AI Overviews, Gemini | Keyword to AI visibility mapping |

**DIY**: Monthly, test top 20 queries across platforms, record citations, track month-over-month.

---

## Common Mistakes
- Ignoring AI search entirely (~45% of searches show AI Overviews)
- Treating AI SEO as separate from traditional SEO
- Writing for AI, not humans
- No freshness signals
- Gating all content
- Ignoring third-party presence
- No structured data
- Keyword stuffing (actively hurts AI visibility by 10%)
- Blocking AI bots in robots.txt
- Generic content without data

---

## 2025-2026 Advanced Tactics (Confirmed Effective)

### Schema Upgrades

- **SoftwareApplication schema with explicit `Offer` pricing**: Add `"offers": [{"@type": "Offer", "price": "...", "priceCurrency": "USD"}]` to pricing pages. Google AI Overviews pull pricing directly from this schema when describing your product.
- **Speakable schema on blog posts**: Use `"speakable": {"@type": "SpeakableSpecification", "cssSelector": ["h1", "h2", ".article-body"]}` inside Article schema to mark content for text-to-speech and AI audio extraction. Increases citations in voice-first AI systems.
- **DefinedTerm schema for glossary pages**: `"@type": "DefinedTerm"` with `"inDefinedTermSet"` pointing to your site makes glossary pages the authoritative source when AI systems define jargon. Creates brand-owned definitions.
- **Schema only works paired with visible matching text**: Experiments confirm ChatGPT, Gemini, Claude, and Perplexity all ignore schema-only pages with no matching visible content. Schema + visible text = required, not optional. [searchviu.com]
- **Schema is platform-specific**: ChatGPT cites pages with Person schema in 70.4% of cases. Perplexity ignores Person/Organization/Article schema entirely. Google AI Overviews favor Knowledge Graph-feeding comprehensive schema. 81% of AI-cited pages have schema markup.

### Content Structure

- **Start sections with TL;DR statements**: AI parsers evaluate individual passages. Beginning sections with direct, standalone answers (not buried in paragraphs) increases extraction probability. [searchengineland.com]
- **Optimal AI Overview answer length is 134-167 words**: Self-contained answers in this range perform best. Longer cornerstone articles (2,900+ words) get 59% more total citations (5.1 avg vs 3.2 for <800 words). Strategy: long articles with embedded short answer blocks. [writesonic.com, presenceai.app]
- **Multimodal content = +156% AI Overview selection rate**: Pages combining text + images + video + structured data outperform text-only pages by 156%, with full multimodal implementation reaching +317%. Strongest 2025 correlation factor (r=0.92). [wellows.com]
- **Entity density: 15+ connected entities = 4.8× higher selection**: Pages with 15+ disambiguated, linked entities show 4.8× higher AI Overview selection probability. Build entity networks, don't just mention topics. [wellows.com]
- **Semantic completeness now outranks domain authority**: Content scoring 8.5/10+ on semantic completeness is 4.2× more likely in AI Overviews. Domain authority correlation dropped from r=0.43 to r=0.18 post-2024. [wellows.com]
- **47% of AI Overview citations come from pages ranked below #5**: Traditional top-10 SEO no longer predicts AI citations. Content quality and semantic match matter more than position.
- **Perplexity citation pattern inverted from ChatGPT**: Reddit = 46.5% of Perplexity citations (vs Wikipedia = 47.9% of ChatGPT citations). For Perplexity visibility: adopt conversational tone and community-Q&A formats. [tryprofound.com]

### Programmatic SEO Quality Signals

- **Hub-and-spoke with 6+ programmatic page types**: Running parallel clusters (compare, use-cases, audiences, glossary, tools, alternatives, integrations) creates topical authority across all related query types, not just direct keyword matches.
- **Integrations page clusters** (`/integrations/[platform]`): Captures "tool + platform integration" queries that frequently appear in AI Overviews. Each page should include FAQ schema targeting "Does [tool] work with [platform]?" questions.
- **Build 5-10 cornerstone articles before scaling programmatic pages**: Programmatic pages fail on domains lacking foundational trust. Hand-written authoritative cores first, then scale to hundreds of programmatic pages. [whalesync.com]
- **Every programmatic page needs original localized value**: Google's thin content definition = "product descriptions copied directly from merchants." AI-assisted uniqueness per page is essential — not template text with variable substitution only. [whalesync.com]
- **Internal linking delivered bigger ranking gains than new backlinks in 2024-2025**: Reorganizing internal link architecture outperformed external link acquisition. Internal links are "authority plumbing" — PageRank flows to priority pages. John Mueller called it "one of the biggest things you can do." [ideamagix.com, searchengineland.com]

### AI Crawler Access (Extended Allowlist)

The basic 5-bot list in the audit section is insufficient. Explicit `Allow` rules for all 19+ known AI crawlers:

```
# AI crawlers — explicit allow
User-agent: GPTBot
Allow: /
User-agent: ChatGPT-User
Allow: /
User-agent: ClaudeBot
Allow: /
User-agent: anthropic-ai
Allow: /
User-agent: PerplexityBot
Allow: /
User-agent: Google-Extended
Allow: /
User-agent: Bingbot
Allow: /
User-agent: Bytespider
Allow: /
User-agent: meta-externalagent
Allow: /
User-agent: cohere-ai
Allow: /
User-agent: YouBot
Allow: /
User-agent: CCBot
Allow: /
User-agent: Amazonbot
Allow: /
User-agent: DuckDuckBot
Allow: /
User-agent: Applebot
Allow: /
User-agent: FacebookBot
Allow: /
```

### llms.txt Enrichment

Beyond a basic page list, include in `llms.txt`:
- Capability descriptions (what the product does, for whom)
- Pricing tiers with plan names and key limits
- Unique value propositions vs. alternatives
- Primary use cases with concrete examples

AI crawlers use `llms.txt` to accurately describe your product in responses. A sparse page-list-only file underutilizes this signal.

---

## 2025-2026 SaaS-Specific & Structural Insights

### GEO / AI Citations

- **AI citation growth**: AI citations jumped 527% Jan–May 2025 — programmatic SEO + GEO is now table-stakes, not a differentiator.
- **Citation Share as a core metric**: Track presence across 4 platforms: ChatGPT, Perplexity, Gemini, Google AI Overviews. Single-platform monitoring misses distribution.
- **Entity optimization framing for LLMs**: Structure pages around 1 primary entity + 3–6 supporting entities explicitly linked to Wikipedia/Wikidata. This replaces keyword density as the targeting mechanism for AI retrieval.
- **Monthly refreshes for evolving topics**: Content freshness is a GEO-specific ranking signal independent of traditional SEO. AI systems prioritize recent updates on tech/compliance topics — quarterly cadence is insufficient for fast-moving categories.
- **Answer density rule**: 1 statistic per 150–200 words; direct answer in first 40–60 words (complements the passage-length guidance above — use both together).

### Topical Authority & Category Pages

- **Category pages now outrank individual pillar pages** when structured with dense internal linking. A well-linked category page beats a standalone pillar on competitive terms.
- **Topical authority > backlinks for long-term visibility**: 50 interconnected pages on one topic beats scattered content + 100 backlinks. Depth-of-coverage is the durable moat.
- **Internal linking density thresholds for programmatic SEO**: Each page needs 8–15 outbound links to relevant pages AND 5–10 inbound links from peers. Poor linking structure triggers quality penalties at scale (not just rankings — indexation too).
- **Hierarchy chain that outranks isolated pages**: pillar → cluster → category → post. Pages not slotted into this chain get less PageRank flow and weaker topical clustering signals.
- **Tags vs. Categories distinction**: Categories = high-level themes users return to; Tags = subtopics/use cases. Conflating them confuses Google's topic clustering and dilutes category page authority.

### SaaS-Specific

- **"How-it-works" pages require video + comparison content to rank**: Text-only process pages get buried. Pair with competitive comparisons — AI citations frequently pull comparison content from these pages.
- **Minimum content thresholds for programmatic pages**: 500+ words of unique content + 30% differentiation vs. similar pages on the site. Pages under 300 words risk thin-content penalties at scale.
- **Weekly quality signal monitoring for programmatic sites** (not monthly): crawl patterns, indexation ratio, and performance metrics degrade faster on large programmatic builds. Monthly cadence catches problems too late.
