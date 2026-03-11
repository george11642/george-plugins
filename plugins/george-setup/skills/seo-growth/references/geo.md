# GEO (Generative Engine Optimization) Reference

## Quick Reference

**GEO = Generative Engine Optimization** -- Optimizing content to be cited by AI search engines. AI search engines don't rank pages -- they **cite sources**. Being cited is the new "ranking #1".

## Workflow

### Step 1: Website Audit
- Check meta tags, robots.txt, sitemap
- Verify AI bot access (GPTBot, ChatGPT-User, PerplexityBot, ClaudeBot, anthropic-ai, Google-Extended, Bingbot)

### Step 2: Keyword Research
Use WebSearch to research target keywords -- search volume, difficulty, competitor strategies, long-tail opportunities.

### Step 3: GEO Optimization

Apply the **9 Princeton GEO Methods**:

| Method | Visibility Boost | How to Apply |
|--------|:---------------:|--------------|
| **Cite Sources** | +40% | Add authoritative citations and references |
| **Statistics Addition** | +37% | Include specific numbers and data points |
| **Quotation Addition** | +30% | Add expert quotes with attribution |
| **Authoritative Tone** | +25% | Use confident, expert language |
| **Easy-to-understand** | +20% | Simplify complex concepts |
| **Technical Terms** | +18% | Include domain-specific terminology |
| **Unique Words** | +15% | Increase vocabulary diversity |
| **Fluency Optimization** | +15-30% | Improve readability and flow |
| ~~Keyword Stuffing~~ | **-10%** | **AVOID -- hurts visibility** |

**Best Combination:** Fluency + Statistics = Maximum boost

### Step 4: Traditional SEO Optimization

**Meta Tags Template:**
```html
<title>{Primary Keyword} - {Brand} | {Secondary Keyword}</title>
<meta name="description" content="{Compelling description with keyword, 150-160 chars}">
<meta property="og:title" content="{Title}">
<meta property="og:description" content="{Description}">
<meta property="og:image" content="{Image URL 1200x630}">
<meta property="og:url" content="{Canonical URL}">
<meta property="og:type" content="website">
<meta name="twitter:card" content="summary_large_image">
```

### Step 5: Schema Markup

Key JSON-LD types: WebPage, Article, FAQPage, Product, Organization, SoftwareApplication, HowTo

**FAQPage Schema** (+40% AI visibility):
```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [{
    "@type": "Question",
    "name": "What is [topic]?",
    "acceptedAnswer": {
      "@type": "Answer",
      "text": "According to [source], [answer with statistics]."
    }
  }]
}
```

## Platform-Specific Optimization

### ChatGPT
- Branded domain authority (cited 11% more than third-party)
- Update content within 30 days (3.2x more citations)
- Build backlinks (>350K referring domains = 8.4 avg citations)

### Perplexity
- Allow PerplexityBot in robots.txt
- Use FAQ Schema (higher citation rate)
- Host PDF documents (prioritized for citation)
- Focus on semantic relevance over keywords

### Google AI Overview (SGE)
- Optimize for E-E-A-T
- Use structured data
- Build topical authority (content clusters + internal linking)
- Include authoritative citations (+132% visibility)

### Microsoft Copilot / Bing
- Ensure Bing indexing
- Optimize for Microsoft ecosystem (LinkedIn, GitHub mentions help)
- Page speed < 2 seconds
- Clear entity definitions

### Claude AI
- Ensure Brave Search indexing (Claude uses Brave, not Google)
- High factual density (data-rich content preferred)
- Clear structural clarity (easy to extract)

## Content Structure for GEO

- Use "answer-first" format (direct answer at top)
- Clear H1 > H2 > H3 hierarchy
- Bullet points and numbered lists
- Tables for comparison data
- Short paragraphs (2-3 sentences max)

## Validation

- Google Rich Results Test for schema
- Schema.org Validator
- Manual site: search on Google and Bing
- Check AI bot access in robots.txt

## Reference Files (from seo-geo)

- platform-algorithms.md -- Detailed ranking factors per platform
- geo-research.md -- Princeton GEO research (9 methods)
- schema-templates.md -- JSON-LD templates
- seo-checklist.md -- Complete SEO audit checklist
- tools-and-apis.md -- Tools and API reference
