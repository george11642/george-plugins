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
