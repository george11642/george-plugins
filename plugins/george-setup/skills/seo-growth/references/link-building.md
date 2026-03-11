# Link Building Reference

## Overview

Link building in 2025 is defined by quality over quantity. Google's algorithms — and AI citation models — reward topical authority and editorial relevance. A single link from a tier-1 publication outweighs hundreds of directory submissions. GEO adds a new dimension: AI systems cite sources with strong backlink profiles and established authority, so link building now serves both traditional rankings and AI visibility.

---

## Backlink Audit Framework

### Step 1: Inventory Your Profile

Pull full backlink export from Ahrefs or Semrush. Key data points per link:
- Referring domain rating (DR/DA)
- Link type (dofollow / nofollow / UGC / sponsored)
- Anchor text
- Page the link points to
- Traffic to referring page (estimated)
- Date acquired

### Step 2: Identify Toxic Links

Disavow file patterns — links that warrant disavowal:

```
# Disavow file format (Google Search Console)
# One domain or URL per line
domain:example-pbn-network.com
domain:spam-directory-site.net
https://lowquality-blog.com/specific-post-with-bad-link
```

Toxic link signals:
- Domain is pure spam/malware (spam score > 60 in Moz)
- Anchor text is exact-match keyword manipulation at scale
- Site is irrelevant niche with no real traffic
- Links appear in footers/sidebars across hundreds of pages
- Part of obvious link scheme or private blog network (PBN)
- Foreign-language spam with no relevance

**Disavow conservatively.** Google ignores most spam automatically. Only disavow if you've received a manual penalty or have a clear pattern of unnatural links.

### Step 3: Domain Authority Assessment

| Tool | Metric | What It Measures |
|------|--------|-----------------|
| Ahrefs | Domain Rating (DR) | Strength of referring domain backlink profile |
| Moz | Domain Authority (DA) | Moz's link-based ranking prediction score |
| Semrush | Authority Score | Composite score (backlinks + organic traffic + spam) |
| Majestic | Trust Flow / Citation Flow | Link quality vs link volume ratio |

**Target thresholds for outreach:**
- DR 40+ for general link building
- DR 60+ for competitive niches
- Any relevant niche-authority site regardless of DR (relevance > raw score)

### Step 4: Competitor Backlink Gap Analysis

Process:
1. Export backlinks for top 3-5 ranking competitors for target keyword set
2. Find domains linking to 2+ competitors but NOT to you (gap opportunities)
3. Prioritize by: relevance, DR, likelihood of acquiring (editorial vs. paid)
4. Create outreach list sorted by opportunity score

Tools: Ahrefs Link Intersect, Semrush Backlink Gap, Moz Link Explorer

---

## Link Building Playbooks

### 1. Broken Link Building

**Concept**: Find 404 pages on authoritative sites that other pages link to. Offer your content as a replacement.

**Process**:
1. Find relevant resource pages or content hubs in your niche
2. Crawl for broken outbound links (Screaming Frog, Check My Links Chrome extension)
3. Identify what the dead page was about (Wayback Machine)
4. Only proceed if you have (or can create) a better replacement
5. Outreach: "Hey, I noticed this link on your [page] is broken — I wrote an updated resource that covers [topic]. Would you consider linking to it?"

**Success rate**: 5-15% response rate; 30-50% of responses result in a link
**Best for**: Resource-heavy niches (finance, health, tech, education)

### 2. Skyscraper Technique

**Concept**: Find content with many backlinks, create a definitively better version, then outreach to everyone linking to the original.

**Process**:
1. Search for your target keyword in Ahrefs Content Explorer
2. Filter for pages with 50+ referring domains
3. Analyze gaps: outdated data, missing topics, poor UX, no visuals
4. Build 10x version: more data, better design, deeper coverage, updated stats
5. Outreach to all sites linking to original: "You linked to [old article] — I wrote a more comprehensive version with [specific improvements]. Would you consider updating your link?"

**Success metrics**: Aim for 30+ referring domains within 90 days of launch
**Common mistake**: Building similar content and calling it "10x." The improvement must be genuinely substantial.

### 3. Resource Page Link Acquisition

**Concept**: Many sites maintain "useful resources" or "best tools" pages. Getting listed provides a clean, editorial link.

**Finding resource pages**:
```
# Google search operators
site:[competitor.com] intitle:"resources"
"[your niche]" + "useful resources"
"[your niche]" + "helpful links"
inurl:resources "your keyword"
```

**Outreach approach**: Keep it brief. Mention why your resource fits their list specifically. Don't send a generic pitch.

### 4. HARO / Help A Reporter Out (Expert Contribution)

**Concept**: Journalists and bloggers request expert sources. Provide a compelling quote and earn a link.

**Current landscape (2025)**:
- HARO merged into Connectively (now Cision)
- Alternatives: Qwoted, SourceBottle, ProfNet, Terkel, Featured.com
- Many publishers send direct requests via LinkedIn or Twitter

**Response formula**:
1. Answer the specific question asked (don't pivot to a pitch)
2. Provide data, stats, or a unique perspective
3. Keep response under 150 words for email, 300 for in-depth requests
4. Include credentials in your bio line
5. Follow up once after 48 hours

**Volume**: Respond to 5-10 queries/week for meaningful link volume

### 5. Guest Posting Strategy

**2025 reality**: Thin guest posts on low-quality blogs provide minimal value. Editorial standards have risen.

**Quality signals for target sites**:
- Real organic traffic (verify with Ahrefs/Semrush traffic estimate)
- Editorial review process (they reject pitches)
- Author bios link to real people
- Comments and social engagement
- Content is on-topic with your niche

**Pitch framework**:
1. Read 3+ recent posts on the site
2. Propose 3 specific title ideas with brief outline
3. Explain why their audience benefits from this topic
4. Link to 2-3 of your best published pieces as samples

**Link placement**: One contextual link to your site in the body (not just bio). Link to a resource, not a commercial page — editors reject commercial links.

### 6. Digital PR (Data Studies, Surveys, Industry Reports)

**Highest ROI link building tactic for authoritative sites.**

**Content types that earn links**:
- Original survey data (100+ respondents, topical relevance)
- Annual industry reports ("State of [Industry] 2025")
- Proprietary data analysis (your platform data, anonymized)
- Controversial/surprising findings with strong narrative
- Visual assets (infographics, interactive tools, calculators)

**Distribution process**:
1. Embargo release to top-tier journalists 48-72 hours early
2. Submit to HARO/Qwoted as a source for related topics
3. Post press release to newswires (PR Newswire, Business Wire for top-tier)
4. Pitch niche industry publications directly
5. Repurpose findings into social content with backlink as source

**Realistic outcomes**: 20-50 referring domains from a strong original study; 5-15 from average content

### 7. Unlinked Brand Mentions

**Concept**: Many sites mention your brand without linking. These are the easiest links to acquire — they already like you.

**Finding mentions**:
- Google Alerts for brand name + variations
- Ahrefs Alerts (more comprehensive)
- Mention.com, Brand24
- Semrush Brand Monitoring

**Outreach**: "Thanks for mentioning us in [article]! Would you mind adding a link to [URL]? Makes it easier for readers to find us." Simple, no pitch needed.

**Conversion rate**: 30-50% — highest of any outreach type

### 8. Internal Link Scoring and Siloing (Hub-and-Spoke)

Internal links are link building too — they distribute PageRank and establish topical authority.

**Hub-and-spoke model**:
- **Hub page**: Comprehensive pillar on broad topic (e.g., "Complete Guide to SEO")
- **Spoke pages**: Deep-dives on subtopics (e.g., "Technical SEO Checklist", "Keyword Research")
- Every spoke links back to hub; hub links to all spokes
- Cross-link spokes to each other where topically relevant

**Internal link audit process**:
1. Identify high-value pages (conversions, organic traffic, revenue)
2. Check how many internal links they receive (should be highest-value pages)
3. Find orphan pages (0 internal links) — these get no PageRank
4. Add contextual internal links from high-authority pages to priority targets

**Anchor text for internal links**: Use descriptive, keyword-rich anchor text. Unlike external links, exact-match internal anchors are fine.

---

## Link Velocity Guidelines

**Natural growth patterns**:
- New site: 2-10 new referring domains/month (slow start, gradual ramp)
- Established site: 5-30 new referring domains/month (consistent)
- After PR campaign: spike of 20-100+ over 2-4 weeks, then return to baseline

**Red flags Google watches for**:
- Sudden spike of 100+ new domains in days with no apparent reason
- Anchor text distribution heavily skewed to exact-match commercial terms
- All links from same C-block IPs (PBN signal)
- Links only from new or low-traffic domains

**Anchor text distribution targets** (referring domains, not individual links):
| Anchor Type | Target % |
|-------------|---------|
| Branded (company name, URL) | 40-60% |
| Generic ("click here", "read more", "website") | 15-25% |
| Topical but not keyword (related phrases) | 10-20% |
| Exact-match target keyword | 1-5% |
| Partial-match keyword | 5-10% |

**Dofollow vs nofollow balance**:
- Natural profiles: 60-80% dofollow, 20-40% nofollow
- Heavily nofollow-skewed profiles can still rank well
- Never build exclusively dofollow links — looks unnatural

---

## Tools Reference

| Tool | Use Case | Cost |
|------|----------|------|
| **Ahrefs** | Backlink analysis, competitor gap, prospecting | $99-449/mo |
| **Semrush** | Backlink audit, toxic score, gap analysis | $129-449/mo |
| **Moz Pro** | DA scoring, spam score, link tracking | $99-599/mo |
| **Monitor Backlinks** | Continuous monitoring + alerts | $25-89/mo |
| **Majestic** | Trust Flow/Citation Flow, historical data | $49-399/mo |
| **Pitchbox** | Outreach CRM + automation | $195+/mo |
| **BuzzStream** | Outreach relationship management | $24-999/mo |
| **Screaming Frog** | Broken link finding, crawl | Free up to 500 URLs |
| **Google Search Console** | Verify links, disavow upload | Free |

---

## 2025 Context: GEO Requires Higher Topical Authority

AI systems (ChatGPT, Perplexity, Claude, Gemini) are not just ranking pages — they're evaluating overall site authority when deciding which sources to cite. Sites with strong topical authority (many high-quality links from relevant sources) appear in AI-generated answers at higher rates.

**Key implication**: Link building now serves dual purpose:
1. Traditional Google rankings (PageRank signal)
2. AI citation likelihood (authority signal for LLMs)

**Topical authority signals that help AI citation**:
- Multiple high-DR links from niche-relevant domains
- Mentions in Wikipedia, academic papers, major publications
- Press coverage in recognized industry outlets
- Links from established brands in your category

Content cited in AI responses tends to have 3x the average referring domain count of non-cited content in the same niche (based on 2024-2025 studies from Ahrefs and Semrush).

---

## Common Mistakes

- **Buying links at scale**: Google's SpamBrain detects paid link patterns reliably in 2025
- **Low-quality guest posts**: DR 10 sites with no real traffic provide minimal value
- **Ignoring relevance**: A DR 80 link from an unrelated niche is worth less than a DR 40 niche-relevant link
- **Anchor text over-optimization**: >10% exact match triggers Penguin-era penalties
- **No follow-up on outreach**: First email response rate is 5-15%; second email adds 20-30% more responses
- **Building links to homepages only**: Distribute links to deep content and commercial pages too
- **Ignoring internal links**: Internal link equity distribution is free and often more impactful than new external links
