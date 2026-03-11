---
name: research-tools
description: "Use when researching topics, finding YouTube videos, analyzing sources with NotebookLM, or doing requirements gathering interviews. Triggers on research, find videos, YouTube search, analyze sources, NotebookLM, research pipeline, deep interview, interview me, requirements gathering, Socratic, yt-dlp, transcript, audio overview, infographic, mind map, study guide, FAQ, briefing doc, find and analyze, research for me, analyze these videos, competitive research."
metadata:
  version: 1.0.0
---

# Research Tools

Route research, analysis, and requirements-gathering tasks to the correct workflow.

## Task Router

| Task | Reference | Key Actions |
|------|-----------|-------------|
| Analyze sources with NotebookLM, generate deliverables | [references/notebooklm-workflow.md](references/notebooklm-workflow.md) | Create notebook, add sources, ask questions, generate audio/infographic/FAQ |
| Search YouTube for videos, fetch transcripts | [references/youtube-search.md](references/youtube-search.md) | yt-dlp search, structured results table, VTT transcript extraction |
| End-to-end research: YouTube -> NotebookLM -> Obsidian | [references/research-pipeline.md](references/research-pipeline.md) | Chain all 3 tools, save structured notes to vault |
| Socratic requirements gathering, spec crystallization | [references/interview-technique.md](references/interview-technique.md) | Ambiguity scoring, challenge agents, spec document generation |

## Quick Decision

- **"Analyze these sources"** -> NotebookLM workflow
- **"Find videos about X"** -> YouTube search
- **"Research X for me" / "find and analyze"** -> Full pipeline
- **"Interview me" / "I have a vague idea"** -> Deep interview
- **URL provided directly** -> Skip search, go to NotebookLM or transcript

## MCP Tools Required

Use ToolSearch at task start to load:
- `mcp__notebooklm__*` — NotebookLM notebook management and questions
- `mcp__obsidian__*` — Obsidian vault note creation (for pipeline saves)

## Shared Principles

- Always return full YouTube URLs so they can be passed to NotebookLM as sources
- NotebookLM handles its own transcription — do not pre-fetch transcripts when passing to NotebookLM
- Visual deliverables (infographic, mind map) can take 5-15 minutes — set expectations
- Deep interview: one question at a time, target weakest clarity dimension, never batch
- Research pipeline default: 10 videos, analysis only (escalate to deliverable if requested)

## Layer 3 Skills

- `notebooklm-research` — NotebookLM MCP workflow for source analysis and deliverable generation
- `youtube-research` — YouTube video search and transcript extraction via yt-dlp
- `research-pipeline` — Full YouTube -> NotebookLM -> Obsidian orchestration
- `deep-interview` — Socratic requirements gathering with mathematical ambiguity scoring
