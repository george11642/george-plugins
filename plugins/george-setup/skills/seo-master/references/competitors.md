# Competitor & Alternative Pages Reference

## Page Formats

### Format 1: [Competitor] Alternative (Singular)
- **Intent**: User actively looking to switch
- **URL**: `/alternatives/[competitor]` or `/[competitor]-alternative`
- **Keywords**: "[Competitor] alternative", "switch from [Competitor]"
- **Structure**: Why people look for alternatives > You as the alternative > Detailed comparison > Who should switch (and who shouldn't) > Migration path > Social proof from switchers > CTA
- **Tone**: Empathetic, helpful guide

### Format 2: [Competitor] Alternatives (Plural)
- **Intent**: User researching options, earlier in journey
- **URL**: `/alternatives/[competitor]-alternatives`
- **Keywords**: "[Competitor] alternatives", "tools like [Competitor]"
- **Structure**: Common pain points > Criteria framework > List of alternatives (you first + 4-7 real options) > Comparison table > Detailed breakdown > Recommendation by use case > CTA
- **Tone**: Objective guide

### Format 3: You vs [Competitor]
- **Intent**: Direct comparison
- **URL**: `/vs/[competitor]`
- **Keywords**: "[You] vs [Competitor]", "[Competitor] vs [You]"
- **Structure**: TL;DR (2-3 sentences) > At-a-glance table > Detailed comparison by category (Features, Pricing, Support, Ease of use, Integrations) > Who each is best for > Testimonials from switchers > Migration support > CTA
- **Tone**: Confident but fair

### Format 4: [Competitor A] vs [Competitor B]
- **Intent**: User comparing two competitors (not you)
- **URL**: `/compare/[competitor-a]-vs-[competitor-b]`
- **Keywords**: "[A] vs [B]", "[A] or [B]"
- **Structure**: Overview of both > Comparison by category > Who each is best for > The third option (introduce yourself) > Three-way comparison table > CTA
- **Tone**: Objective analyst

---

## Index Pages

Each format needs an index page:
- **Alternatives Index** (`/alternatives`): Lists all singular alternative pages
- **Alternatives Plural Index** (`/best-alternatives`): Lists all roundup pages
- **Vs Comparisons Index** (`/vs` or `/compare`): Lists all comparison pages

Index pages pass link equity, help discovery, and can rank for broad terms.

---

## Content Architecture

### Centralized Competitor Data
Single source of truth per competitor (YAML):
- Name, website, tagline, founded, headquarters
- Positioning: primary use case, target audience, market position
- Pricing: model, tiers, free tier details
- Features: rated 1-5 per category
- Strengths, weaknesses (be honest)
- Best for, not ideal for
- Common complaints (from reviews)
- Migration notes: difficulty, data export, time estimate

### Page Generation
Each page pulls from centralized data. Update once, propagate everywhere.

---

## Core Principles

1. **Honesty Builds Trust** -- Acknowledge competitor strengths, be accurate about limitations
2. **Depth Over Surface** -- Go beyond checklists, explain why differences matter
3. **Help Them Decide** -- Be clear about who you're best for AND who competitor is best for
4. **Modular Architecture** -- Centralized competitor data, single source of truth

---

## Section Templates

### TL;DR Summary
"[Competitor] excels at [strength] but struggles with [weakness]. [Your product] is built for [focus], offering [differentiator]. Choose [Competitor] if [their use case]. Choose [You] if [your use case]."

### Comparison Tables
Go beyond checkmarks -- use descriptions:
| Feature | You | Competitor |
|---------|-----|-----------|
| Feature A | Full support with [detail] | Basic support, [limitation] |

Organize by category: Core functionality, Collaboration, Integrations, Security, Support.

### Pricing Comparison
Include: tier breakdown table, what's included, hidden costs/add-ons, total cost for sample team size.

### Who It's For
Specific use cases, team types, workflows, and priorities for each product. Include ideal customer persona in 1-2 sentences.

### Migration Section
What transfers, what needs reconfiguration, migration support offered, customer quotes about switching.

---

## SEO Considerations

| Format | Primary Keywords | Secondary Keywords |
|--------|-----------------|-------------------|
| Alternative (singular) | [Competitor] alternative | alternative to [Competitor], switch from [Competitor] |
| Alternatives (plural) | [Competitor] alternatives | best [Competitor] alternatives, tools like [Competitor] |
| You vs Competitor | [You] vs [Competitor] | [Competitor] vs [You] |
| A vs B | [A] vs [B] | [B] vs [A], [A] or [B] |

**Internal linking**: Between related competitor pages, from feature pages, from blog posts, hub page to all.

**Schema**: FAQPage for common questions on comparison pages.

---

## Research Process (5 Phases)

### Phase 1: Product Trial
- Sign up for a free trial (use a fresh email to get the new-user experience)
- Complete the onboarding fully — document every step and friction point
- Use the product for its primary use case — take notes on UX, missing features, bugs
- Screenshot key UI patterns (pricing page, feature pages, onboarding)

### Phase 2: Pricing Deep-Dive
- Document current pricing, tiers, and included features (competitors change pricing frequently)
- Identify hidden costs: per-seat add-ons, API overage fees, implementation/onboarding fees, premium support costs
- Check for annual vs. monthly pricing differences
- Determine whether enterprise pricing is published or "contact sales"

### Phase 3: Review Mining
Mine G2, Capterra, TrustRadius, and relevant app marketplaces for:

**Praise patterns** (what they do better than you — be honest about this):
- Group into 3-5 recurring themes
- Quote verbatim where possible (use these to acknowledge competitor strengths credibly)

**Complaint patterns** (their weaknesses — your opportunity):
- Group into 3-5 recurring themes
- These become the "why people look for alternatives" section on your alternative pages

**Specific quotes**: Collect 8-10 quotes in each direction. Real user language on comparison pages is far more credible than company-written claims.

### Phase 4: Customer Interviews
Talk to:
- **Your customers who switched from this competitor**: What drove the switch? What do they miss? What surprised them?
- **Prospects who chose competitor over you**: Why? What was the deciding factor? What would have changed their mind?
- **Lost deals where competitor was the alternative**: What did they say in the sales process?

These conversations produce the most authentic content for comparison pages and help you avoid blind spots.

### Phase 5: Content Audit
- Read all of their comparison pages (how do they position against you?)
- Review their feature pages for claims you need to address
- Check their changelog or blog for recent feature releases
- Read their documentation quality (relevant for "ease of use" comparisons)
- Monitor their positioning changes over time (are they moving upmarket? Targeting new personas?)

---

## Maintenance Cadence

Stale competitor pages erode trust — users will verify your claims and bounce if they find inaccuracies.

### Quarterly Verification (Every 3 Months)
- [ ] Verify all pricing figures are current (check competitor's pricing page directly)
- [ ] Check for major new features or product changes (review their changelog)
- [ ] Update any "as of [date]" timestamps on the page
- [ ] Verify review score figures (G2/Capterra scores change)
- [ ] Check that comparison table rows are still accurate

### Annual Full Refresh
- [ ] Re-run all 5 research phases from scratch
- [ ] Update centralized competitor YAML data file
- [ ] Rewrite sections that are significantly outdated
- [ ] Add/remove features from comparison table as products evolve
- [ ] Refresh customer quotes and testimonials (use recent ones)
- [ ] Update migration difficulty assessment (tools improve export capabilities over time)
- [ ] Review and update the "who it's best for" recommendations

### Trigger-Based Updates
Update immediately when:
- Competitor announces major pricing change
- Competitor launches a feature that closes a gap vs. your product
- A competitor gets acquired or announces significant changes
- A viral post or news story brings major attention to the competitor

---

## Comparison Table Psychology

### Beyond Checkmarks

Checkmark tables (✓ / ✗) are the minimum viable comparison. They tell users what exists but not what it means. Go deeper:

**Level 1 (Weak):** Binary checkmarks only
| Feature | You | Competitor |
|---------|-----|-----------|
| API Access | ✓ | ✗ |

**Level 2 (Better):** Descriptive values
| Feature | You | Competitor |
|---------|-----|-----------|
| API Access | REST + GraphQL, 100k calls/mo | Not available |

**Level 3 (Best):** Outcome-oriented with context
| Feature | You | Competitor |
|---------|-----|-----------|
| API Access | Full REST + GraphQL API, 100k calls/month on Pro, unlimited on Business. Webhook support for real-time sync. | No API — integrations require Zapier (additional cost) |

### Organizing Tables for Decision-Making

Don't organize comparison tables by internal product structure. Organize by decision relevance:

1. **Usage limits** (users, storage, projects) — the most common upgrade/downgrade driver
2. **Core functionality** (does it do the main thing they need?)
3. **Collaboration features** (team-size-dependent decisions)
4. **Integrations** (workflow compatibility)
5. **Support and service** (risk mitigation for buyers)
6. **Security and compliance** (enterprise gating factors)
7. **Pricing** (always near the bottom — value before price)

### Acknowledge Competitor Strengths

Include a row or section where the competitor wins. This is counterintuitive but critical:

- Users who are evaluating will verify your claims — they know the competitor's strengths
- If you only show your wins, the table looks biased and loses credibility
- Acknowledging competitor strengths makes your wins more believable
- It also shows you've done real research, not just marketing

**Example:**
| Category | You | Competitor | Notes |
|---------|-----|-----------|-------|
| Template library | 50+ templates | 200+ templates | [Competitor] has a much larger template ecosystem |
| Customization | Highly flexible | Limited customization | [You] wins for teams with unique workflows |

This builds the trust that makes the rest of the comparison credible.

---

## Section Templates (20+ Examples)

### TL;DR Summary (Always lead with this)
```markdown
**TL;DR**: [Competitor] excels at [strength] but struggles with [weakness].
[Your product] is built for [focus], offering [key differentiator].
Choose [Competitor] if [their ideal use case]. Choose [You] if [your ideal use case].
```

### Feature Comparison Section
```markdown
## Feature Comparison

### [Feature Category]

**[Competitor]**: [2-3 sentences describing their approach, strengths, and limitations]

**[Your product]**: [2-3 sentences describing your approach, what you do better, honest tradeoff]

**Bottom line**: [Competitor] if [scenario]. [You] if [scenario].
```

### Pricing Comparison Section
```markdown
## Pricing

| | [Competitor] | [Your Product] |
|---|---|---|
| Free tier | [Details or "None"] | [Details or "None"] |
| Starter | $X/user/mo | $X/user/mo |
| Business | $X/user/mo | $X/user/mo |
| Enterprise | Custom | Custom |

**What's included**: [Competitor]'s $X plan includes [list], while [Your product]'s
equivalent $X plan includes [list, including what's different].

**Hidden costs to consider**: [Competitor] charges extra for [X]. [Your product]
includes [Y] in base pricing with no add-on required.

**For a 10-person team**: [Competitor] costs approximately $[X]/year.
[Your product] costs approximately $[Y]/year, [with/without] [key included item].
```

### Who It's For Section
```markdown
## Who Should Choose [Competitor]

[Competitor] is the right choice if you:
- [Specific use case or workflow need]
- [Team type or size]
- [Existing tool ecosystem or requirement]
- [Priority that this competitor serves better]

**Ideal [Competitor] customer**: [1-2 sentence persona description with specifics]

## Who Should Choose [Your Product]

[Your product] is built for teams who:
- [Specific use case or workflow need]
- [Team type or size]
- [Priority that you serve better]
- [Specific requirement you uniquely address]

**Ideal [Your product] customer**: [1-2 sentence persona description with specifics]
```

### Migration Section
```markdown
## Switching from [Competitor]

### What transfers
- [Data type]: [How easily, format, any limitations]
- [Data type]: [How easily, format, any limitations]

### What needs reconfiguration
- [Item]: [Why it doesn't transfer and estimated effort]
- [Item]: [Why it doesn't transfer and estimated effort]

### Migration support we offer
- [Free import tool / white-glove migration service]
- [Migration guide link]
- [Timeline: "Most teams are fully migrated within X days"]

### What customers say about switching
> "[Specific quote with outcome: time saved, problem solved, surprise]"
> — [Name], [Role] at [Company]
```

### Social Proof — Switchers
```markdown
## What [Competitor] Users Say After Switching

> "[Quote specifically about the switch experience and outcome]"
> — [Name], [Role] at [Company], [Industry]

> "[Quote about specific feature or workflow improvement]"
> — [Name], [Role] at [Company], [Industry]

### Results after switching
- [Company] reduced [metric] by [amount] after switching from [Competitor]
- [Company] went from [old state] to [new state] in [timeframe]
```

### Research Process Section (for plural alternatives pages)
```markdown
## How We Evaluated These Alternatives

We spent [X hours/days] evaluating [number] tools against these criteria:
- [Criterion 1]: [Why this matters]
- [Criterion 2]: [Why this matters]
- [Criterion 3]: [Why this matters]

We signed up for free trials, tested each tool with [specific use case],
mined [G2/Capterra] reviews for user sentiment, and verified pricing directly
from each vendor's website as of [Month Year].
```

### FAQ Section (with schema opportunity)
```markdown
## Frequently Asked Questions

### What is the best alternative to [Competitor]?
[Direct answer that positions you, with honest context about when other options are better]

### Is [Your Product] cheaper than [Competitor]?
[Specific comparison with current pricing. Be accurate — users verify this.]

### Can I import my data from [Competitor]?
[Specific answer: what imports, what doesn't, how long it takes, what support is available]

### How long does it take to switch from [Competitor] to [Your Product]?
[Specific, honest estimate by company size or data volume]

### Does [Your Product] have [specific feature users value in Competitor]?
[Direct answer. If yes, explain how. If no, explain what you offer instead and why]
```

### Third-Option Introduction (for A vs B pages)
```markdown
## Wait — Have You Considered a Third Option?

[Competitor A] and [Competitor B] are both solid tools, but they share some common
limitations: [list 2-3 shared weaknesses that your product solves].

If [shared limitation] is a concern for your team, [Your Product] was built specifically
to solve it. Here's how it compares to both:

| | [Competitor A] | [Competitor B] | [Your Product] |
|---|---|---|---|
| [Key differentiator] | ... | ... | ... |

[Brief CTA to try your product or see the full comparison]
```

---

## Research Process

### Phase 1: Product Trial
Sign up for a free trial. Use it for its primary use case. Document every friction point and screenshot key UI patterns.

### Phase 2: Pricing Deep-Dive
Current pricing, tiers, hidden costs (API overages, add-ons, implementation fees). Document what's included vs. what costs extra.

### Phase 3: Review Mining
G2, Capterra, TrustRadius. Group into praise themes and complaint themes. Collect verbatim quotes.

### Phase 4: Customer Interviews
Talk to customers who switched from this competitor. Talk to prospects who chose the competitor over you.

### Phase 5: Content Audit
Their comparison pages, feature pages, changelog, and documentation. How do they position against you?

**Maintenance**: Quarterly pricing/feature verification. Annual full refresh. Immediate update when competitor makes major changes.
