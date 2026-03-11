# YouTube Search & Transcript Extraction

Search YouTube and return structured video results using yt-dlp. Optionally fetch transcripts for video content.

## Step 1: Search

```bash
yt-dlp "ytsearch{N}:{query}" \
  --flat-playlist \
  --print "%(title)s\t%(uploader)s\t%(view_count)s\t%(duration_string)s\t%(webpage_url)s" \
  --no-download 2>/dev/null
```

- Replace `{N}` with the number of results (default: 10, more if user asks)
- Replace `{query}` with the user's search query
- If a URL is provided directly, skip search and go straight to transcript fetching

## Output Format (Search Results)

Present results as a numbered table:

| # | Title | Channel | Views | Duration | URL |
|---|-------|---------|-------|----------|-----|
| 1 | ... | ... | ... | ... | ... |

After the table, briefly summarize patterns you notice (popular channels, content gaps, view count outliers).

## Step 2: Fetch Transcripts (Optional)

**When to fetch**: User explicitly asks to "transcribe", "get the content of", "scrape", or "read" a YouTube video, or wants to analyze what a video says directly.

**Skip this step** if the user only wants to find videos or pass URLs to another tool (e.g., NotebookLM handles its own transcription).

For each video that needs a transcript:

```bash
yt-dlp --write-auto-subs --skip-download --sub-format vtt \
  --output "/tmp/yt_%(id)s" "VIDEO_URL" 2>/dev/null
```

Then clean the VTT file with Python:

```python
import re
with open('/tmp/yt_VIDEOID.en.vtt') as f:
    content = f.read()
# Remove WEBVTT header, timestamps, deduplicate lines
lines = re.sub(r'WEBVTT.*?\n\n', '', content, flags=re.DOTALL)
lines = re.sub(r'\d{2}:\d{2}:\d{2}\.\d{3} --> .*\n', '', lines)
text = '\n'.join(dict.fromkeys(l.strip() for l in lines.split('\n') if l.strip()))
print(text)
```

Present the cleaned transcript under a heading with the video title. If no `.en.vtt` file is created, auto-subs may be unavailable — note this and move on.

## Notes

- View counts may show as "None" for some results — display as "N/A"
- If yt-dlp errors on a query, try simplifying the search terms
- Always return the full YouTube URL so it can be used as a NotebookLM source
- Transcript fetching is for standalone use; for the research pipeline, NotebookLM handles transcription internally
