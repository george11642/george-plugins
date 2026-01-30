---
name: ralph-publish
description: Manually publish a specific content file to configured platforms.
---

# /ralph-publish

Manually publish a content file to the configured publishing targets.

## What to do

1. Get the file path from the user's argument: `/ralph-publish <file-path>`
   - If no path given, list available drafts from `content/drafts/` and ask which to publish

2. Verify the file exists and is a markdown file with valid frontmatter

3. Read `.ralph/config.json` for publishing configuration

4. Run the publisher:
   ```
   node $PLUGIN_DIR/scripts/src/publish/index.js <file-path>
   ```

5. Report results:
   - Primary publish: success/failure + URL
   - Cross-posts: success/failure + URLs for each platform
   - Any errors encountered

6. If successful, move the file from `content/drafts/` to `content/published/`
