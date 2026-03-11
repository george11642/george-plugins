---
name: mcp-obsidian
description: "Use when reading, writing, searching, or organizing notes in an Obsidian vault. Triggers on Obsidian, Obsidian vault, read note, write note, update note, search vault, global search, list notes, manage tags, frontmatter, wikilinks, knowledge base, save to Obsidian, Obsidian MCP, search and replace in vault, delete note, note organization, vault maintenance, atomic notes, Zettelkasten."
---

# MCP Obsidian

Knowledge base management via Obsidian MCP (lazy-loaded via ToolSearch).

## Loading

```
ToolSearch: +obsidian
```

## MCP Tools

| Task | Tool | Key Params |
|------|------|------------|
| Read note | `mcp__obsidian__obsidian_read_note` | path |
| Update note | `mcp__obsidian__obsidian_update_note` | path, content |
| Search vault | `mcp__obsidian__obsidian_global_search` | query |
| List notes | `mcp__obsidian__obsidian_list_notes` | folder (optional) |
| Manage tags | `mcp__obsidian__obsidian_manage_tags` | path, tags |
| Frontmatter | `mcp__obsidian__obsidian_manage_frontmatter` | path, key, value |
| Search & replace | `mcp__obsidian__obsidian_search_replace` | search, replace |
| Delete note | `mcp__obsidian__obsidian_delete_note` | path |

## Workflows

### Research Capture
1. `global_search` -- check if topic already exists
2. If not: `update_note` to create new note with findings
3. `manage_frontmatter` -- add date, status, source metadata
4. `manage_tags` -- add relevant tags for discoverability

### Knowledge Retrieval
1. `global_search` with topic keywords
2. `read_note` on best matches
3. Synthesize across multiple notes if needed

### Vault Maintenance
1. `list_notes` to scan a folder
2. `read_note` on stale entries
3. `manage_frontmatter` to update status (draft/review/published)
4. `search_replace` for bulk renames or link updates

## Note Structure Best Practices

### Frontmatter Template
```yaml
---
date: 2026-03-08
status: draft | review | published
tags: [topic, subtopic]
source: URL or reference
---
```

### Content Conventions
- **Wikilinks**: `[[Related Note]]` for internal connections
- **Tags**: `#topic/subtopic` for cross-cutting categorization
- **Headings**: H2 for sections, H3 for subsections -- enables outline navigation
- **Callouts**: `> [!note]` / `> [!warning]` for emphasis

### Naming Conventions
- Use descriptive titles: "React Server Components Patterns" not "RSC"
- Prefix with date for journal entries: "2026-03-08 Research Session"
- Use folders for broad categories, tags for cross-cutting concerns

## Best Practices

- **Search before creating** -- avoid duplicates in the vault
- **Frontmatter on every note** -- date and tags at minimum
- **Link liberally** -- wikilinks are cheap, orphan notes are expensive
- **One idea per note** -- atomic notes compose better than monoliths
- **Update status** -- mark notes as draft/review/published for triage
