# Infographics Reference

AI-generated infographics using Gemini MCP tools. No design skills or API keys required.

## Workflow

1. (Optional) Research phase gathers accurate facts via Perplexity Sonar
2. `mcp__gemini__gemini_image` generates the infographic from natural language
3. `mcp__gemini__gemini_analyze` reviews quality against document-type threshold
4. If score >= threshold: DONE (early stop)
5. If below: `mcp__gemini__gemini_image_edit` refines based on critique
6. Repeats until quality met or max iterations reached

## CLI Usage

```bash
python skills/infographics/scripts/generate_infographic.py [OPTIONS] PROMPT

Options:
  -o, --output PATH         Output file path (required)
  -t, --type TYPE           Infographic type preset
  -s, --style STYLE         Industry style preset
  -p, --palette PALETTE     Colorblind-safe palette
  -b, --background COLOR    Background color (default: white)
  --doc-type TYPE           Document type for quality threshold
  --iterations N            Max refinement iterations (default: 3)
  --research                Enable auto data gathering
  -v, --verbose             Verbose output
  --list-options            List all available options
```

## Infographic Types

| Type | Flag | Best For |
|------|------|----------|
| Statistical | `--type statistical` | Numbers, percentages, survey results |
| Timeline | `--type timeline` | Milestones, history, evolution |
| Process | `--type process` | Step-by-step, workflows, tutorials |
| Comparison | `--type comparison` | Side-by-side, pros/cons, before/after |
| List | `--type list` | Tips, facts, key points, summaries |
| Geographic | `--type geographic` | Regional data, demographics, maps |
| Hierarchical | `--type hierarchical` | Org charts, pyramids, priority levels |
| Anatomical | `--type anatomical` | Visual metaphors, labeled systems |
| Resume | `--type resume` | CVs, portfolio highlights, skills |
| Social | `--type social` | Instagram, LinkedIn, Twitter posts |

## Style Presets

| Style | Colors | Best For |
|-------|--------|----------|
| `corporate` | Navy, steel blue, gold | Business, finance |
| `healthcare` | Medical blue, cyan | Medical, wellness |
| `technology` | Tech blue, slate, violet | Software, AI, data |
| `nature` | Forest green, mint, earth | Environmental, organic |
| `education` | Academic blue, coral | Learning, academic |
| `marketing` | Coral, teal, yellow | Social media, campaigns |
| `finance` | Navy, gold, green/red | Investment, banking |
| `nonprofit` | Warm orange, sage, sand | Social causes |

## Colorblind-Safe Palettes

| Palette | Description |
|---------|-------------|
| `wong` | Most widely recommended (orange, sky blue, green, blue, vermillion) |
| `ibm` | IBM's accessible palette (ultramarine, indigo, magenta, orange, gold) |
| `tol` | 12-color extended palette for many categories |

## Quality Thresholds

| Doc Type | Threshold | Use Case |
|----------|-----------|----------|
| marketing | 8.5/10 | Must be compelling |
| report | 8.0/10 | Professional quality |
| presentation | 7.5/10 | Clear and engaging |
| social | 7.0/10 | Social media |
| internal | 7.0/10 | Internal use |
| draft | 6.5/10 | Working drafts |
| default | 7.5/10 | General purpose |

## Quality Criteria (scored by gemini_analyze)

1. **Visual Hierarchy & Layout** (0-2): Clear hierarchy, logical flow, balanced
2. **Typography & Readability** (0-2): Readable, bold headlines, no overlapping
3. **Data Visualization** (0-2): Prominent numbers, clear charts/icons, labels
4. **Color & Accessibility** (0-2): Professional colors, contrast, colorblind-friendly
5. **Overall Impact** (0-2): Professional, no visual bugs, achieves goal

## Research Integration

Use `--research` flag for accurate, up-to-date data:
```bash
python scripts/generate_infographic.py \
  "Global renewable energy adoption rates" \
  -o figures/renewable.png --type statistical --research
```

Research provides: 5-8 key facts, context, specific data points, source citations, 2023-2026 focus.

**Enable research for**: statistics, market data, scientific info, current events.
**Skip research for**: conceptual infographics, internal docs, user-provided data.

## Prompt Tips

**Be specific** (include data points):
```
"5 benefits of meditation: reduces stress by 40%, improves focus,
better sleep quality, lower blood pressure, emotional balance"
```

**Include numbers**:
```
"Market growth from $10B (2020) to $45B (2025), CAGR 35%"
```

**Specify visual elements**:
```
"Timeline showing 5 milestones with icons for each event"
```

## Gemini MCP Tools

- `mcp__gemini__gemini_image` - Publication-quality generation
- `mcp__gemini__gemini_image_fast` - Fast/draft generation
- `mcp__gemini__gemini_image_edit` - Refine existing infographic
- `mcp__gemini__gemini_analyze` - Score and critique

## Related Skills

- **scientific-schematics**: Technical flowcharts, circuit diagrams, biological pathways
- **scientific-slides**: Infographic elements for presentations
