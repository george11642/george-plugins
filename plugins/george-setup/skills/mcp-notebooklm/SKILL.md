---
name: mcp-notebooklm
description: "Use when analyzing sources with NotebookLM, creating research notebooks, or generating audio overviews and study materials. Triggers on NotebookLM, create notebook, add sources to notebook, ask NotebookLM, notebook question, synthesize sources, audio overview, podcast summary, generate infographic, mind map, study guide, FAQ generation, briefing document, NotebookLM MCP, research notebook, source analysis, multi-source synthesis, notebook deliverable."
---

# MCP NotebookLM

Deep research and analysis via NotebookLM MCP (lazy-loaded via ToolSearch).

## Loading

```
ToolSearch: +notebooklm
```

## MCP Tools

| Task | Tool |
|------|------|
| Create notebook | `mcp__notebooklm__add_notebook` |
| Select notebook | `mcp__notebooklm__select_notebook` |
| Get details | `mcp__notebooklm__get_notebook` |
| Ask question | `mcp__notebooklm__ask_question` |
| List notebooks | `mcp__notebooklm__list_notebooks` |
| Search notebooks | `mcp__notebooklm__search_notebooks` |
| Update sources | `mcp__notebooklm__update_notebook` |
| Remove notebook | `mcp__notebooklm__remove_notebook` |
| Cleanup data | `mcp__notebooklm__cleanup_data` |
| Health check | `mcp__notebooklm__get_health` |
| Session mgmt | `list_sessions`, `close_session`, `reset_session` |
| Auth | `mcp__notebooklm__setup_auth`, `mcp__notebooklm__re_auth` |

## Standard Workflow

### 1. Create or Reuse Notebook
```
list_notebooks -> check for existing match
add_notebook(title="Topic Name", sources=[url1, url2, ...])
```
Sources: YouTube URLs (`https://youtube.com/watch?v=...`), web URLs, or raw text. Up to 50 per notebook.

### 2. Extract Insights
Ask specific, focused questions:
```
ask_question("What are the key themes across these sources?")
ask_question("What topics get the most engagement and why?")
ask_question("What content gaps exist that aren't covered?")
ask_question("What are the main takeaways for someone new to this?")
```

### 3. Request Deliverables (if needed)
Use `ask_question` with clear requests:
- **Audio overview**: "Generate an audio overview / podcast summary"
- **Infographic**: "Create an infographic of key findings"
- **Mind map**: "Create a mind map of main concepts"
- **Study guide**: "Create a study guide with key concepts and questions"
- **FAQ**: "Generate a FAQ based on these sources"
- **Briefing doc**: "Create a briefing document of the most important points"

Visual deliverables (infographic, mind map) can take 5-15 minutes.

### 4. Synthesize and Return
Summarize analysis clearly. Include any links or content NotebookLM returned.

## Best Practices

- **One notebook per research topic** -- keeps analysis focused
- **Diverse sources** -- mix video, text, docs for balanced perspective
- **Specific questions** -- "What pricing strategies do top channels use?" beats "Tell me about the videos"
- **Search before creating** -- reuse existing notebooks when possible
- **Clean up** -- use `cleanup_data` to remove stale notebooks periodically

## Auth Issues

If NotebookLM returns auth errors:
1. Try `mcp__notebooklm__re_auth` first
2. If that fails, `mcp__notebooklm__setup_auth` for fresh setup
3. Check `mcp__notebooklm__get_health` for service status
