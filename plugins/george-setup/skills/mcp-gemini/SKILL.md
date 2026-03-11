---
name: mcp-gemini
description: "Use when calling Gemini AI for image analysis, image generation, grounded web search, code execution, text-to-speech, or video analysis. Triggers on Gemini, gemini_analyze, gemini_image, analyze image, generate image, Gemini search, grounded search, gemini_code_execute, run Python in sandbox, Gemini TTS, text to speech, gemini_video, video analysis, Gemini MCP, gemini_embed, embeddings, CAPTCHA solve, image edit, Gemini chat."
---

# MCP Gemini

Multimodal AI capabilities via Gemini MCP (lazy-loaded via ToolSearch).

**CRITICAL**: Model is `gemini-3.1-flash-lite-preview`. The older `2.5-flash` and `2.0-flash` are DEPRECATED and return 404.

## Loading

```
ToolSearch: +gemini
```

## MCP Tools

| Task | Tool | When to Use |
|------|------|-------------|
| Chat | `mcp__gemini__gemini_chat` | Complex reasoning, long context |
| Chat (fast) | `mcp__gemini__gemini_chat_flash` | Quick answers, simple tasks |
| Analyze image | `mcp__gemini__gemini_analyze` | Screenshots, UI mockups, diagrams, CAPTCHAs |
| Generate image | `mcp__gemini__gemini_image` | Create images from text prompts |
| Fast image gen | `mcp__gemini__gemini_image_fast` | Quick image generation |
| Edit image | `mcp__gemini__gemini_image_edit` | Modify existing images |
| Code execution | `mcp__gemini__gemini_code_execute` | Run Python in sandboxed env |
| Web search | `mcp__gemini__gemini_search` | Grounded search with citations |
| Text-to-speech | `mcp__gemini__gemini_tts` | Generate audio from text |
| Video analysis | `mcp__gemini__gemini_video` | Analyze video content |
| Video status | `mcp__gemini__gemini_video_status` | Check video processing status |
| Embed text | `mcp__gemini__gemini_embed` | Generate text embeddings |

## Common Patterns

### CAPTCHA Solving
```
1. Screenshot the CAPTCHA: browser-agent screenshot -> /tmp/captcha.png
2. gemini_analyze(image_path="/tmp/captcha.png", prompt="Extract the text from this CAPTCHA")
3. Type the extracted text back into the form
```

### Image Analysis (UI Review)
```
gemini_analyze(
  image_path="/tmp/screenshot.png",
  prompt="Analyze this UI screenshot. Identify layout issues, accessibility problems, and visual inconsistencies."
)
```

### Grounded Web Search
```
gemini_search(query="latest React 19 features and breaking changes")
```
Returns results with citations -- use for current information beyond training data.

### Sandboxed Code Execution
```
gemini_code_execute(code="import pandas as pd\ndf = pd.DataFrame({'a': [1,2,3]})\nprint(df.describe())")
```
Runs Python with common data science libraries available.

### Video Analysis
```
gemini_video(video_url="https://youtube.com/watch?v=...", prompt="Summarize key points")
gemini_video_status(operation_id="...") -- check if processing complete
```
Video analysis can be async -- use `video_status` to poll.

### Image Generation
```
gemini_image(prompt="A clean, modern SaaS dashboard with analytics cards")
gemini_image_fast(prompt="Simple icon of a rocket ship") -- faster, lower quality
gemini_image_edit(image_path="/tmp/original.png", prompt="Change the background to dark blue")
```

## Decision Tree

```
Need current info? -> gemini_search (grounded, cited)
Need to understand an image? -> gemini_analyze
Need to generate an image? -> gemini_image (quality) or gemini_image_fast (speed)
Need to run Python? -> gemini_code_execute
Need video insights? -> gemini_video + gemini_video_status
Need audio output? -> gemini_tts
Need embeddings? -> gemini_embed
General reasoning? -> gemini_chat (complex) or gemini_chat_flash (simple)
```

## Gotchas

- **Model version**: ALWAYS `gemini-3.1-flash-lite-preview` -- 2.5-flash and 2.0-flash return 404
- **Video is async**: `gemini_video` starts processing; poll with `gemini_video_status`
- **Image paths**: Use absolute paths (`/tmp/screenshot.png`) not relative
- **Search is grounded**: Results include citations -- use for factual claims
- **Code sandbox**: Has pandas, numpy, etc. but no network access or file system persistence
