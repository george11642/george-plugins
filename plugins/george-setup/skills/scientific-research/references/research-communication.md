# Research Communication: Translating Science for Diverse Audiences

## Overview

Research communication is the practice of making scientific findings accessible, meaningful, and actionable for audiences beyond the academic peer. It includes policy briefs, press releases, social media, video abstracts, and graphical abstracts. Effective science communication requires understanding your audience and deliberately adapting your message — not just simplifying your abstract.

---

## Science Communication Principles

### Know Your Audience (Audience Analysis)

Before any communication, explicitly ask:
- Who is this for? (general public, policymakers, journalists, clinicians, community members)
- What do they already know? (baseline knowledge, prior exposure to this topic)
- What do they care about? (what is at stake for them)
- What do you want them to do, think, or feel after reading/watching? (your communication goal)
- Where will they encounter this? (Twitter, policy brief, press release, TED talk — each has different norms)

Different audiences require not just different vocabulary but different **frames**, **metaphors**, and **evidence standards**.

### The Curse of Knowledge

Research by Wiemann and others demonstrates that experts systematically underestimate how much background knowledge is needed to understand their field. You have forgotten what it was like not to know. Symptoms:
- Using jargon without defining it
- Assuming readers understand acronyms (MCAR, RCT, DAG)
- Beginning with methods before establishing why anyone should care
- Treating complexity as a virtue

**Cure**: Read your draft to someone outside your field; ask them to interrupt whenever they lose the thread.

### Analogy and Metaphor for Abstract Concepts

Analogies accelerate understanding by linking the unfamiliar to the familiar. Good analogy rules:
- Match the structural relationship, not just surface features
- Acknowledge where the analogy breaks down (every analogy does)
- Use common objects and experiences as anchors

Examples:
- "P-value" → "If you flipped a fair coin 20 times and got 17 heads, the p-value is how often a fair coin would do that — it helps you decide if the coin is fair"
- "Effect size" → "Statistical significance tells you whether an effect exists; effect size tells you whether it matters"
- "Confidence interval" → "Our 95% CI of [2.3, 4.7] is like a weather forecast that says 'it'll be between 2 and 5 degrees' — not a single number, but a range we're reasonably confident contains the truth"

### The Inverted Pyramid (Lead With the Finding)

Academic papers bury the finding in results and discussion. Science communication inverts this:

**Inverted pyramid structure**:
1. Most important: The finding and why it matters (first sentence)
2. Essential context: What was studied, on whom, how
3. Supporting details: Methods, statistics, limitations
4. Background: Prior work, disciplinary context

"Patients taking Drug X had 40% fewer hospital admissions over two years" is a better first sentence than "In this randomized controlled trial examining the efficacy of Drug X in adult patients with Type 2 diabetes mellitus..."

### KISS (Keep It Simple, Scientist)

Not "dumbing down" — distilling. The goal is clarity, not condescension.

**Readability guidelines**:
- Target Flesch-Kincaid grade level 8-10 for general public (check in Word or with `textstat` Python library)
- Sentences: average 15-20 words; no sentence over 40 words
- Paragraphs: 3-5 sentences; one idea per paragraph
- Active voice: "We found X" not "X was found"
- Concrete nouns: "50 patients" not "patient cohort"
- Specific numbers: "twice as likely" not "substantially more likely"

---

## Policy Briefs

### When to Write a Policy Brief

Policy briefs translate research evidence into practical recommendations for policymakers, government agencies, NGOs, or funding bodies. They are read by people with 5-15 minutes, not 2 hours.

### Structure

**Title**: Specific, actionable, 10-15 words. Not "Effects of X" but "Why Expanding X Could Reduce Y by Z%"

**Executive Summary** (~100 words, first):
- The problem in one sentence
- The key finding in one sentence
- The top recommendation in one sentence

**The Problem** (~150-200 words):
- Why this matters to your reader
- Scale: who is affected, how many, at what cost
- Current policy context: what is being done (or not)

**The Evidence** (~300-400 words):
- What research shows, with specific numbers
- Quality of evidence (brief: systematic review, RCT — not "a study found")
- Acknowledge uncertainty and limitations honestly
- Cite 3-6 key references (not academic-style; just author/year or footnotes)

**Policy Options / Recommendations** (~200 words):
- 2-4 numbered, specific recommendations
- For each: What to do, who should do it, by when
- Tie recommendations directly to evidence
- Acknowledge trade-offs

**Further Information**:
- Contact, links, QR code to full report

### Language and Formatting

- Avoid jargon: "people with low income" not "socioeconomically disadvantaged populations"
- Avoid hedging: "The evidence suggests that it may be possible..." → "Evidence shows..."
- Use pull quotes, callout boxes, bullets for scannability
- 1-2 pages maximum
- Include one key figure or infographic
- Use government/funder language: "cost-effective", "scalable", "evidence-based", "return on investment"

---

## Press Releases and Science News

### Press Release Structure

A press release should answer: who did what, when, where, why it matters.

**Headline** (the most important sentence you write):
- Lead with the finding or implication, not "Researchers study X"
- Bad: "University scientists investigate role of sleep in memory consolidation"
- Good: "Getting less than 7 hours of sleep impairs memory as much as staying awake for 24 hours, study finds"

**Dateline**: City, Date — [Institution name]

**Lead paragraph**: Core finding + why it matters + who did it (1-2 sentences max)

**Body paragraphs** (inverted pyramid):
1. Quote from lead researcher (direct, not bureaucratic — editors use real quotes)
2. What was studied: sample, design, methods (one paragraph)
3. Key numerical findings (be specific)
4. Quote from co-author, collaborator, or external expert
5. Broader context: how this advances the field
6. Limitations and next steps (brief)
7. Funding acknowledgment

**Boilerplate**: Standard "About [Institution]" paragraph

### Quote Selection and Framing

Good researcher quotes for press: specific, punchy, not repeating what the text already says. Bad: "Our findings suggest that sleep deprivation may have negative effects on cognitive performance." Good: "This is the first time we've been able to show, in a real-world setting, that sleep loss hits memory as hard as an all-nighter."

### Common Misrepresentation Traps

- **Causation vs correlation**: "X causes Y" vs "X is associated with Y" — be precise
- **Relative vs absolute risk**: "doubles the risk" (relative) vs "increases risk from 1% to 2%" (absolute)
- **Population vs individual**: Population-level finding does not mean every individual is affected
- **Preliminary findings**: Preprint or conference presentation should be labeled as not peer-reviewed

### Working with Journalists

- **Embargo**: Agree not to release information until a specified date/time. Allows time for reporting.
- **Off the record**: Information shared but cannot be published — must be explicitly agreed before speaking
- **Background**: Can use the information but not attribute to you by name
- **On the record**: Everything can be published and attributed
- Never ask to "approve" the story; you can offer to fact-check specific quotes
- Respond quickly — journalists work on tight deadlines

---

## Social Media for Research

### Twitter/X Threads for Papers

A 10-tweet structure for announcing a new paper:

1. **Hook tweet**: The headline finding + key number + "new paper in [journal]" + figure image
2. **Background**: Why this question matters; what we didn't know
3. **What we did**: Brief study design (1 tweet)
4. **Key finding 1** (with figure or data visualization)
5. **Key finding 2**
6. **What this means**: Implication for theory/practice
7. **Limitations**: Brief, honest
8. **Future directions**: What comes next
9. **Gratitude**: Co-authors, participants, funders
10. **Link to paper + preprint + OSF repo + thread summary**

**Tips**:
- Post the thread, then RT the first tweet with "Thread:" to increase visibility
- Use alt text on all images (accessibility)
- Tag collaborators and relevant accounts
- Post at peak times (Tuesday-Thursday, 9am-12pm in target timezone)

### LinkedIn for Professional Impact

- Longer-form summaries (400-800 words) perform well
- Lead with the "so what" for practitioners
- Use document upload (PDF of key figure or visual summary)
- Tag collaborators; use relevant hashtags sparingly
- Comments from engaged professional community can broaden reach further than Twitter

### Altmetrics and Impact Tracking

- **Altmetric**: Aggregates online attention (news, social media, policy documents) for any paper with DOI. See your paper's Altmetric score at altmetric.com or journal website.
- **PlumX**: Similar to Altmetric; tracks usage stats, captures, social activity, citations
- Include altmetric data in grant applications to demonstrate broader impact
- Track: policy citations (if paper cited in government documents), media coverage, social media reach

---

## Video Abstracts

### Why Video Abstracts

Many journals request or incentivize video abstracts. Studies show papers with video abstracts receive more views and citations. Growing expectation in competitive fields.

### 90-Second Structure

| Segment | Duration | Content |
|---|---|---|
| Hook | 10 sec | One compelling question or statistic |
| Problem | 15 sec | What didn't we know? Why does it matter? |
| Methods | 15 sec | What did we do? (one or two sentences) |
| Finding | 25 sec | What did we find? (key result + visual) |
| Impact | 15 sec | Why does this matter beyond the lab? |
| Call to action | 10 sec | Read the paper / link / contact |

### Production Tools

**Screen recording + narration**:
- **ScreenPal** (formerly Screencast-O-Matic): Free tier available; easy screen + webcam recording
- **Loom**: Fast, free for short videos; good for narrated slide walkthroughs
- **OBS Studio**: Free, open-source; more complex but professional quality

**Animation/explainer**:
- **Animaker**: drag-and-drop; good for illustrative animations without video
- **Powtoon**: Similar to Animaker; academic pricing available
- **Adobe Express** (formerly Spark): Templates for research; free tier

**Post-production**:
- **DaVinci Resolve**: Free, professional-grade video editor
- **CapCut**: Free, excellent auto-captions

### Closed Captions

Captions are both an accessibility requirement and SEO asset (video platforms index caption text).
- Auto-captions are a starting point; always review and correct them
- YouTube auto-captions for downloading and editing
- SRT format for uploading to any platform
- Accuracy standard: 99% for accessibility compliance

---

## Graphical Abstracts

### Purpose

A single-panel visual summary of your paper — increasingly required or encouraged by journals (Cell, Elsevier, Nature family). Readers decide whether to read the full paper based partly on the graphical abstract.

### Common Formats by Journal

- **Cell/Elsevier**: 1:1 or landscape ratio; often a process diagram or result summary; ~132mm width
- **Nature family**: Typically not required but encouraged; posted with article
- **ACS journals**: Required since 2014; 4:3 ratio, 500×375 to 1500×1125 px

### Design Principles for Non-Designers

**Structure**: Three sections: (1) Question/Problem → (2) Approach → (3) Finding/Implication

**Visual hierarchy**: Most important element largest; eye moves from top-left to bottom-right; ensure key finding stands out

**Color**: Use 2-3 colors maximum; use your field's conventions (blue = control, red = treatment is common in biomedical); always colorblind-safe (test with Coblis or Adobe Color)

**Text**: Minimal — key labels only; large enough to read at 50% zoom; sans-serif font

**Tools**:
- **BioRender** (biorender.com): Best for biological/biomedical figures; free for non-publication use; institutional license for publication
- **Inkscape**: Free, vector-based; steep learning curve
- **Adobe Illustrator**: Industry standard; expensive
- **Canva**: Good templates; limited scientific figure library
- **Affinity Designer**: One-time purchase alternative to Illustrator

**Checklist before submission**:
- [ ] Does it stand alone without reading the paper?
- [ ] Is the key finding visually prominent?
- [ ] Is all text legible at print size?
- [ ] Colorblind-safe palette?
- [ ] Correct resolution (at least 150 DPI; 300 DPI preferred)?
- [ ] Correct dimensions per journal specifications?
- [ ] No copyrighted images (only original art or licensed figures)?

---

## Science Communication Across Disciplines

### Biomedical / Clinical

- Quantify benefit in absolute risk reduction AND number needed to treat (NNT), not just relative risk
- Distinguish efficacy (controlled trial) from effectiveness (real-world)
- Distinguish surrogate outcomes (biomarkers) from patient-centered outcomes (hospitalizations, mortality)

### Social / Behavioral Sciences

- Be explicit about generalizability limits (WEIRD sample: Western, Educated, Industrialized, Rich, Democratic)
- Distinguish statistical significance from practical significance
- Frame findings in terms of everyday behaviors and decisions

### Environmental / Climate

- Be clear about scientific consensus vs scientific uncertainty
- Use local, tangible examples where possible
- Distinguish emissions mitigation (reducing the problem) from adaptation (managing consequences)

### Computational / Data Science

- Code availability is now expected by general science audiences
- Interactive visualizations (Shiny, Plotly Dash, Observable) can communicate findings better than static figures
- Always report benchmark comparisons fairly (same test set, same preprocessing)

---

## Key Resources

- Alan Alda Center for Communicating Science: https://www.aldacenter.org
- COMPASS SciComm: https://www.compassscicomm.org
- The Open Notebook (science journalism): https://www.theopennotebook.com
- BioRender: https://biorender.com
- Altmetric: https://www.altmetric.com
- Braun, V., & Clarke, V. (2013). *Successful Qualitative Research*. Sage. (Chapter on dissemination)
- Olson, R. (2015). *Houston, We Have a Narrative*. University of Chicago Press. (Narrative structure for scientists)
