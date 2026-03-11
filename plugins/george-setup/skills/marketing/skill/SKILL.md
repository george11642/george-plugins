---
name: marketing
description: >
  Use for content marketing, copywriting, social media, email campaigns, launch strategy, and growth.
  Triggers on blog post, social media post, email campaign, newsletter, drip campaign, Product Hunt,
  go-to-market, GTM, launch plan, marketing copy, ad copy, content calendar, SEO content, Twitter thread,
  LinkedIn post, landing page copy, pSEO, programmatic SEO, content strategy, brand voice, marketing funnel,
  lead magnet, paid ads, Facebook ads, Google ads, campaign, retargeting, subject line, welcome sequence,
  content repurposing, hook formula, headline, CTA, conversion copy, growth marketing, marketing psychology,
  persuasion.
---

# Marketing Skill

Unified marketing skill covering content, copy, social, email, launches, ads, and psychology. Uses progressive disclosure: this file routes to detailed references.

## Task Router

| User Intent | Reference File | Key Frameworks |
|---|---|---|
| Launch plan, Product Hunt, go-to-market, GTM | `references/launch-playbook.md` | ORB framework, 5-phase launch, PH checklist |
| Landing page copy, headline, CTA, page copy | `references/copywriting.md` | 14 headline formulas, page structure, CTA patterns |
| Edit/review/polish existing copy | `references/copywriting.md` | Seven Sweeps editing framework |
| Social media post, thread, content calendar | `references/social-content.md` | Platform strategy, 5 hook types, templates |
| Email sequence, drip campaign, newsletter | `references/email-sequences.md` | 4 sequence templates, lifecycle audit checklist |
| Paid ads, PPC, ROAS, retargeting | `references/paid-ads.md` | Platform matrix, PAS/BAB copy, optimization levers |
| Persuasion, pricing psychology, conversion | `references/psychology.md` | Top 20 models, challenge-->model lookup table |
| Marketing ideas, growth tactics, brainstorm | `references/tactics-library.md` | 140 categorized tactics, selection by stage/budget |

**Multi-domain requests**: Read multiple reference files. E.g., "launch email sequence" = launch-playbook.md + email-sequences.md.

## Core Principles

1. **Clarity over cleverness** -- if you must choose, choose clear
2. **Benefits over features** -- connect every feature to an outcome
3. **Specificity over vagueness** -- "Cut reporting from 4h to 15min" beats "save time"
4. **Customer language over company language** -- mirror voice-of-customer
5. **Value before ask** -- earn the right to sell through usefulness
6. **One idea per unit** -- one job per email, one CTA per section, one message per ad
7. **Show, don't tell** -- social proof, case studies, and data beat assertions

## Quick-Reference Frameworks

### ORB Framework (Channel Strategy)
- **Owned**: Email, blog, community -- compound over time, no algorithm risk
- **Rented**: Social media, app stores -- speed but no stability, funnel to owned
- **Borrowed**: Guest posts, podcasts, influencers -- instant credibility, convert to owned

### Seven Sweeps (Copy Editing)
Sequential passes, each one dimension:
1. **Clarity** -- Can they understand it?
2. **Voice & Tone** -- Is it consistent?
3. **So What** -- Does every claim answer "why should I care?"
4. **Prove It** -- Is every claim supported?
5. **Specificity** -- Is it concrete enough?
6. **Heightened Emotion** -- Does it make them feel something?
7. **Zero Risk** -- Have we removed every barrier to action?

### Good-Better-Best (Pricing)
Three tiers where the middle is your target. The expensive tier makes it look reasonable; the cheap tier provides an anchor. Use round prices for premium ($500), charm prices for value ($497).

### PAS (Ad Copy)
Problem -- Agitate -- Solve. State the pain, twist the knife, introduce the fix.

### Hook Formulas (Social)
- **Curiosity**: "I was wrong about [common belief]."
- **Story**: "Last week, [unexpected thing] happened."
- **Value**: "How to [outcome] without [pain]:"
- **Contrarian**: "[Common advice] is wrong. Here's why:"
- **Proof**: "We [achieved result] in [timeframe]. Here's how:"

### Headline Formulas (Top 5)
- {Outcome} without {pain}
- Turn {input} into {output}
- {Question highlighting pain}
- The {category} that {differentiator}
- {Number} {people} use {product} to {outcome}

## Dispatch Pattern

For content generation tasks, spawn an agent:

```
Agent: marketing-agent
Args: "Generate [content-type] for [product]. Target audience: [audience]. Tone: [tone]. Focus: [topic/keyword]. Read references/[relevant-file].md for frameworks."
```

### When to Dispatch vs. Handle Inline
- **Dispatch**: Full blog posts, email sequences, content calendars, multi-post social campaigns, landing page rewrites
- **Inline**: Quick headline alternatives, single social post, copy review/feedback, strategy advice, framework selection

## Supported Content Types

| Type | Output Location | Format |
|---|---|---|
| Blog posts | `content/blog/YYYY-MM-DD-slug.md` | 800-1500 words, SEO-optimized |
| Twitter/X threads | `content/social/twitter-slug.md` | 5-7 tweets, hook to CTA |
| LinkedIn posts | `content/social/linkedin-slug.md` | 200-300 words, story-driven |
| Email campaigns | `content/email/campaign-slug.md` | Subject + preview + body |
| Product Hunt copy | `content/launch/producthunt.md` | Tagline, description, comments |
| Landing page copy | In-place edits | Hero, features, proof, FAQ, CTA |
| Ad copy | `content/ads/platform-slug.md` | Headlines, body, CTAs by platform |
| pSEO pages | App pages directory | Template-driven, JSON-LD |

## Integration

- **seo-growth**: Technical SEO after content is generated (sitemaps, structured data, internal linking)
- **analytics-posthog**: Measure content performance post-publish
- **payments-stripe**: Pricing page copy aligned with Stripe plan structure

## Safety

- Never fabricate features not in the codebase
- Never create fake testimonials or statistics
- Mark unknowns with `[PLACEHOLDER: description]`
- All content based on actual product analysis
