# Paid Advertising

## Platform Selection Matrix

| Platform | Best For | Typical CPC | Key Strength |
|---|---|---|---|
| **Google Ads** | High-intent search, capturing existing demand | $1-5+ | Bottom-of-funnel conversions |
| **Meta (FB/IG)** | Demand generation, visual products, broad targeting | $0.50-3 | Creative-driven audience building |
| **LinkedIn** | B2B, decision-makers, job title targeting | $8-15+ | Professional targeting precision |
| **Twitter/X** | Tech audiences, real-time, thought leadership | $0.50-3 | Lower CPMs, amplify organic |
| **TikTok** | Younger demographics (18-34), viral creative | $0.50-2 | Brand awareness, native feel |

### Campaign Types by Platform
- **Google**: Search, Performance Max, Display, YouTube, Demand Gen
- **Meta**: Advantage+ Shopping, Lead Gen, Conversions, Traffic
- **LinkedIn**: Sponsored Content, Message Ads, Lead Gen Forms, Document Ads
- **TikTok**: In-Feed, TopView, Branded Hashtag, Spark Ads

---

## Campaign Structure

```
Account
-- Campaign: [Objective] - [Audience/Product]
   -- Ad Set: [Targeting variation]
      -- Ad 1: [Creative A]
      -- Ad 2: [Creative B]
      -- Ad 3: [Creative C]
```

**Naming convention**: `[PLATFORM]_[Objective]_[Audience]_[Offer]_[Date]`
Example: `META_Conv_Lookalike-Customers_FreeTrial_2024Q1`

### Budget Allocation
- **Testing (first 2-4 weeks)**: 70% proven campaigns, 30% testing
- **Scaling**: consolidate into winners, increase 20-30% at a time, wait 3-5 days between increases

---

## Ad Copy Frameworks

### PAS (Problem-Agitate-Solve)
```
[Problem statement]
[Agitate the pain]
[Introduce solution]
[CTA]
```
> Spending hours on manual reporting every week?
> While you're buried in spreadsheets, competitors are making decisions.
> [Product] automates your reports in minutes.
> Start your free trial -->

### BAB (Before-After-Bridge)
```
[Current painful state]
[Desired future state]
[Your product as the bridge]
```
> Before: Chasing approvals across email, Slack, and spreadsheets.
> After: Every approval tracked, automated, and on time.
> [Product] connects your tools and keeps projects moving.

### Social Proof Lead
```
[Impressive stat or testimonial]
[What you do]
[CTA]
```
> "We cut reporting time by 75%." -- Sarah K., Marketing Director
> [Product] automates the reports you hate building.
> See how it works -->

### Headlines
**Search**: [Keyword] + [Benefit] | [Action] + [Outcome] | [Question] | [Number] + [Benefit]
**Social**: Hook with outcome | Hook with curiosity | Hook with contrarian | Hook with specificity

### CTAs
- **Soft** (awareness): Learn More, See How It Works, Watch Demo, Get the Guide
- **Hard** (conversion): Start Free Trial, Book a Demo, Claim Your Discount
- **Urgency** (when genuine): Limited Time: 30% Off, Offer Ends [Date]

---

## Audience Targeting

### Google
- Keywords (exact, phrase, broad match)
- Remarketing lists for search ads (RLSA)
- Custom intent, in-market, affinity audiences
- Customer match (email list upload)

### Meta
- **Core**: layer interests with AND logic, exclude customers, start broad
- **Custom**: website visitors (by page/behavior), customer lists, engagement audiences
- **Lookalike**: source from best customers by LTV, start 1%, expand to 1-3%

### LinkedIn
- Job function + seniority + company size
- Industry + job title
- Company list + decision-maker titles (ABM)

---

## Retargeting Strategy

| Funnel Stage | Audience | Message | Goal |
|---|---|---|---|
| Top (awareness) | Blog readers, video viewers | Educational, social proof | Move to consideration |
| Middle (consideration) | Pricing/feature page visitors | Case studies, demos, comparisons | Move to decision |
| Bottom (decision) | Cart abandoners, trial users | Urgency, objection handling, offers | Convert |

### Retargeting Windows

| Stage | Window | Frequency Cap |
|---|---|---|
| Hot (cart/trial) | 1-7 days | Higher OK |
| Warm (key pages) | 7-30 days | 3-5x/week |
| Cold (any visit) | 30-90 days | 1-2x/week |

**Always exclude**: existing customers (unless upsell), recent converters (7-14 days), bounced visitors (<10 sec), irrelevant pages

---

## Optimization Levers

### If CPA is too high:
1. Check landing page (problem post-click?)
2. Tighten audience targeting
3. Test new creative angles
4. Improve ad relevance/quality score
5. Adjust bid strategy

### If CTR is low:
- Test new hooks/angles
- Refine targeting (audience mismatch)
- Refresh creative (ad fatigue)
- Improve value proposition

### If CPM is high:
- Expand targeting (too narrow)
- Try different placements
- Improve creative fit (low relevance)
- Adjust bid caps

### Bid Strategy Progression
1. Start with manual or cost caps
2. Gather 50+ conversions
3. Switch to automated (target CPA/ROAS) based on historical data
4. Monitor and adjust

---

## Creative Best Practices

### Images
- Clear product screenshots showing UI
- Before/after comparisons
- Stats as focal point
- Real faces (not stock)
- Bold, readable text (under 20%)

### Video (15-30 sec)
1. Hook (0-3s): pattern interrupt or bold statement
2. Problem (3-8s): relatable pain
3. Solution (8-20s): show product/benefit
4. CTA (20-30s): clear next step

**Tips**: captions always (85% watch muted), vertical for Stories/Reels, native > polished, first 3 seconds decide everything

### Testing Hierarchy
1. Concept/angle (biggest impact)
2. Hook/headline
3. Visual style
4. Body copy
5. CTA

Kill losers in 3-5 days with sufficient spend. Iterate on winners.

---

## Weekly Review Checklist

- [ ] Spend vs. budget pacing
- [ ] CPA/ROAS vs. targets
- [ ] Top and bottom performing ads
- [ ] Audience performance breakdown
- [ ] Frequency check (fatigue risk)
- [ ] Landing page conversion rate
- [ ] Disapproved ads or policy issues

## Attribution Notes
- Platform attribution is inflated
- Use UTM parameters consistently
- Compare platform data to GA4
- Look at blended CAC, not just platform CPA
