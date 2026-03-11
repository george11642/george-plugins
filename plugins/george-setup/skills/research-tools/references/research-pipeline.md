# Research Pipeline: YouTube -> NotebookLM -> Obsidian

The full end-to-end research workflow chaining three tools into one seamless session.

## What You Need From the User

Before starting, confirm:
1. **Topic** — what to research
2. **Deliverable** (optional) — infographic, audio overview, mind map, study guide, FAQ, or just analysis
3. **Number of videos** (default: 10)

If unclear, just start with 10 videos and no specific deliverable.

## Pipeline Steps

### Step 1: YouTube Search

Use yt-dlp to find videos:

```bash
yt-dlp "ytsearch10:{topic}" \
  --flat-playlist \
  --print "%(title)s\t%(uploader)s\t%(view_count)s\t%(duration_string)s\t%(webpage_url)s" \
  --no-download 2>/dev/null
```

Collect the video URLs and titles. Note view count outliers — high-performing videos are good signals.

### Step 2: NotebookLM Analysis

Use ToolSearch to load NotebookLM MCP tools, then:

1. Create a notebook: `add_notebook(title="{Topic} Research - {date}", sources=[...youtube_urls...])`
2. Ask for analysis:
   - "What are the top 5 most important themes across these videos?"
   - "Which videos perform best and why? What content drives views?"
   - "What gaps or opportunities are NOT being covered?"
   - Any user-specific questions
3. If a deliverable was requested, ask NotebookLM to generate it

### Step 3: Save to Obsidian

Use ToolSearch to load Obsidian MCP tools, then save a structured research note.

**Folder structure:** `Research/{Topic}/`

**Main research note** (`Research/{Topic}/analysis.md`):
```markdown
# {Topic} Research
Date: {date}

## Summary
{2-3 sentence overview of what was found}

## Videos Analyzed
| Title | Channel | Views | URL |
|-------|---------|-------|-----|
{table of videos}

## Key Findings
{NotebookLM analysis — themes, patterns, outliers}

## Content Gaps & Opportunities
{What's missing, what could be done differently}

## Deliverable
{Link or description of infographic/audio/etc. if generated}

## Raw Notes
{Any additional detail from NotebookLM}
```

**Index note** (`Research/{Topic}/{Topic}.md`):
```markdown
# {Topic}
Type: Research
Date: {date}
Status: Complete

## Related
[[analysis]]
```

Use `mcp__obsidian__obsidian_update_note` or `mcp__obsidian__obsidian_read_note` for note management.

### Step 4: Report Back

Tell the user:
- What you found (top themes, surprising data points)
- Where the notes are saved in Obsidian
- The deliverable (if requested)
- Any follow-up questions you'd suggest asking NotebookLM

## Example Invocations

- "Research Claude Code and MCP servers for me" -> 10 videos, analysis only
- "Run the research pipeline on AI agents, I want an infographic" -> 10 videos + infographic
- "Find 20 videos about Notion and analyze what's driving views" -> 20 videos, performance analysis

## Style Preferences

Over time, note what the user likes — level of detail, deliverable preferences, analysis angles. When preferences emerge, capture them in CLAUDE.md or suggest updates.
