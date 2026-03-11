#!/usr/bin/env python3
"""
Memory Consolidation System for Claude Code Framework.

Processes flat MEMORY.md entries into structured, deduplicated, topic-organized knowledge.
- Parses by ## headers
- Detects duplicates via exact substring + Jaccard word similarity
- Groups related facts by topic
- Splits large topics into separate files
- Safe: .bak before modify, idempotent
"""

import os
import re
import shutil
import sys
from datetime import datetime
from typing import Dict, List, Tuple

MEMORY_DIR = os.path.expanduser("~/.claude/projects/-home-george/memory")
MEMORY_PATH = os.path.join(MEMORY_DIR, "MEMORY.md")
JACCARD_THRESHOLD = 0.6
TOPIC_SPLIT_THRESHOLD = 20  # lines


def read_file(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def write_file(path: str, content: str) -> None:
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def slugify(text: str) -> str:
    """Convert a header to a filename-safe slug."""
    text = re.sub(r"\(.*?\)", "", text).strip()
    text = text.lower()
    text = re.sub(r"[^a-z0-9\s-]", "", text)
    text = re.sub(r"[\s]+", "-", text).strip("-")
    return text


def parse_sections(content: str) -> List[Tuple[str, str]]:
    """Parse markdown into (header, body) sections. Returns list of tuples."""
    lines = content.split("\n")
    sections = []
    current_header = None
    current_lines = []
    preamble_lines = []

    for line in lines:
        if line.startswith("## "):
            if current_header is not None:
                sections.append((current_header, "\n".join(current_lines)))
            elif current_lines:
                preamble_lines = current_lines[:]
            current_header = line[3:].strip()
            current_lines = []
        else:
            current_lines.append(line)

    if current_header is not None:
        sections.append((current_header, "\n".join(current_lines)))
    elif current_lines:
        preamble_lines = current_lines

    return preamble_lines, sections


def extract_entries(body: str) -> List[str]:
    """Extract individual bullet entries from a section body.
    Handles multi-line entries (indented continuation lines)."""
    entries = []
    current_entry_lines = []

    for line in body.split("\n"):
        if line.startswith("- "):
            if current_entry_lines:
                entries.append("\n".join(current_entry_lines))
            current_entry_lines = [line]
        elif line.startswith("  ") and current_entry_lines:
            current_entry_lines.append(line)
        else:
            if current_entry_lines:
                entries.append("\n".join(current_entry_lines))
                current_entry_lines = []

    if current_entry_lines:
        entries.append("\n".join(current_entry_lines))

    return entries


def get_words(text: str) -> set:
    """Extract word set from text for Jaccard comparison."""
    text = re.sub(r"[*`\[\](){}#>|_~]", " ", text.lower())
    return set(w for w in text.split() if len(w) > 2)


def jaccard_similarity(a: str, b: str) -> float:
    """Compute Jaccard word similarity between two strings."""
    words_a = get_words(a)
    words_b = get_words(b)
    if not words_a or not words_b:
        return 0.0
    intersection = words_a & words_b
    union = words_a | words_b
    return len(intersection) / len(union)


def is_substring_duplicate(a: str, b: str) -> bool:
    """Check if one entry is an exact substring of the other (normalized)."""
    norm_a = re.sub(r"\s+", " ", a.strip().lower())
    norm_b = re.sub(r"\s+", " ", b.strip().lower())
    if len(norm_a) < 20 or len(norm_b) < 20:
        return False
    return norm_a in norm_b or norm_b in norm_a


def deduplicate_entries(entries: List[str]) -> Tuple[List[str], int]:
    """Remove duplicate entries, keeping the most detailed version.
    Returns (deduplicated list, count of duplicates removed)."""
    if not entries:
        return entries, 0

    # Mark entries to remove (index -> True if should be removed)
    remove = [False] * len(entries)
    duplicates_found = 0

    for i in range(len(entries)):
        if remove[i]:
            continue
        for j in range(i + 1, len(entries)):
            if remove[j]:
                continue

            is_dup = False

            # Check exact substring
            if is_substring_duplicate(entries[i], entries[j]):
                is_dup = True

            # Check Jaccard similarity
            if not is_dup and jaccard_similarity(entries[i], entries[j]) > JACCARD_THRESHOLD:
                is_dup = True

            if is_dup:
                # Keep the longer (more detailed) entry
                if len(entries[i]) >= len(entries[j]):
                    remove[j] = True
                else:
                    remove[i] = True
                duplicates_found += 1
                if remove[i]:
                    break  # i is removed, no need to check further

    result = [e for i, e in enumerate(entries) if not remove[i]]
    return result, duplicates_found


def rebuild_section(header: str, entries: List[str]) -> str:
    """Rebuild a section from header and entries."""
    body = "\n".join(entries)
    return body


def create_topic_file(topic_slug: str, header: str, body: str) -> str:
    """Create/update a topic detail file. Returns the filename."""
    filename = f"{topic_slug}.md"
    filepath = os.path.join(MEMORY_DIR, filename)
    content = f"# {header}\n\n{body.strip()}\n"
    write_file(filepath, content)
    return filename


def consolidate():
    """Main consolidation logic."""
    if not os.path.exists(MEMORY_PATH):
        print(f"Error: {MEMORY_PATH} not found")
        sys.exit(1)

    original_content = read_file(MEMORY_PATH)
    original_lines = original_content.split("\n")
    before_count = len(original_lines)

    # Strip old consolidation header if present
    content = original_content
    content = re.sub(r"^Last consolidated:.*\n\n?", "", content)

    preamble_lines, sections = parse_sections(content)

    total_duplicates = 0
    consolidated_sections = []
    topic_files_created = []

    for header, body in sections:
        entries = extract_entries(body)
        deduped, dups = deduplicate_entries(entries)
        total_duplicates += dups

        section_body = rebuild_section(header, deduped)
        section_lines = section_body.strip().split("\n")
        line_count = len(section_lines)

        topic_slug = slugify(header)

        if line_count > TOPIC_SPLIT_THRESHOLD and topic_slug:
            # Split to topic file
            filename = create_topic_file(topic_slug, header, section_body)
            topic_files_created.append(filename)
            # Keep summary in MEMORY.md (first 3 entries + link)
            summary_entries = deduped[:3]
            summary_body = rebuild_section(header, summary_entries)
            summary_body += f"\n- See [{filename}]({filename}) for full details ({line_count} lines)"
            consolidated_sections.append((header, summary_body))
        else:
            consolidated_sections.append((header, section_body))

    # Build consolidated output
    date_str = datetime.now().strftime("%Y-%m-%d %H:%M")
    output_parts = [f"Last consolidated: {date_str}\n"]

    # Preamble (usually just "# Project Memory")
    preamble = "\n".join(preamble_lines).strip()
    if preamble:
        output_parts.append(preamble)

    for header, body in consolidated_sections:
        section_text = f"\n## {header}\n{body.strip()}"
        output_parts.append(section_text)

    output = "\n".join(output_parts).strip() + "\n"
    after_count = len(output.split("\n"))

    # Safety: write .bak first
    bak_path = MEMORY_PATH + ".bak"
    shutil.copy2(MEMORY_PATH, bak_path)

    # Write consolidated
    write_file(MEMORY_PATH, output)

    # Calculate reduction
    if before_count > 0:
        reduction = round((1 - after_count / before_count) * 100)
    else:
        reduction = 0

    print(f"Consolidated: {before_count} lines -> {after_count} lines ({reduction}% reduction), {total_duplicates} duplicates removed")
    if topic_files_created:
        print(f"Topic files created/updated: {', '.join(topic_files_created)}")
    print(f"Backup saved to: {bak_path}")


if __name__ == "__main__":
    consolidate()
