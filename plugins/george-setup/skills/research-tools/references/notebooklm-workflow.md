# NotebookLM Workflow

Use the NotebookLM MCP tools to analyze sources and produce deliverables.

## Available MCP Tools

Use ToolSearch to find these tools before calling them:
- `mcp__notebooklm__list_notebooks` — list existing notebooks
- `mcp__notebooklm__add_notebook` — create a new notebook with sources
- `mcp__notebooklm__select_notebook` — select a notebook to work with
- `mcp__notebooklm__get_notebook` — get notebook details
- `mcp__notebooklm__ask_question` — ask NotebookLM a question about the sources
- `mcp__notebooklm__update_notebook` — update notebook sources or settings
- `mcp__notebooklm__search_notebooks` — search across notebooks
- `mcp__notebooklm__remove_notebook` — delete a notebook
- `mcp__notebooklm__re_auth` / `mcp__notebooklm__setup_auth` — handle authentication

## Standard Workflow

### Step 1: Create or Reuse a Notebook

Check if a relevant notebook already exists:
```
list_notebooks → look for matching topic
```

If creating new:
```
add_notebook(title="Topic Name", sources=[url1, url2, ...])
```

Sources can be YouTube URLs, web URLs, or text content. Up to 50 sources per notebook.

### Step 2: Get Analysis

Ask specific questions to extract insights:
```
ask_question("What are the key themes across these videos?")
ask_question("What topics get the most views and why?")
ask_question("What content gaps exist that aren't covered?")
ask_question("What are the main takeaways for someone new to this topic?")
```

Adapt questions to what the user actually wants to know.

### Step 3: Request a Deliverable (If Asked)

Ask NotebookLM to generate deliverables via `ask_question` with a clear request:

| Deliverable | Prompt |
|-------------|--------|
| Audio overview | "Generate an audio overview / podcast summary of these sources" |
| Infographic | "Create an infographic summarizing the key findings" |
| Mind map | "Create a mind map of the main concepts" |
| Study guide | "Create a study guide with key concepts and questions" |
| FAQ | "Generate a FAQ based on these sources" |
| Briefing doc | "Create a briefing document summarizing the most important points" |

Visual deliverables (infographic, mind map) can take 5-15 minutes. Set expectations with the user.

### Step 4: Return Results

Summarize the analysis clearly. If a deliverable was generated, describe it and include any links or content NotebookLM returned.

## Tips

- If sources are YouTube videos, use the full `https://youtube.com/watch?v=...` URL
- If NotebookLM needs auth, use `re_auth` or `setup_auth`
- NotebookLM handles its own transcription — do not pre-fetch transcripts when passing YouTube URLs
