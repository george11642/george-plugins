#!/usr/bin/env node

/**
 * Ralph Marketer V2 — Content Listing
 *
 * Lists content sources from the database.
 *
 * Usage:
 *   node scripts/src/content/list.js [options]
 *
 * Options:
 *   --type drafts|published|calendar|all   Filter content type (default: all)
 *   --format table|json                    Output format (default: table)
 *   --project-dir /path/to/project         Project directory (default: cwd)
 */

import { resolve } from "path";
import { getDb } from "../db/query.js";

// ---------------------------------------------------------------------------
// CLI argument parsing
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const args = argv.slice(2);
  let projectDir = process.cwd();
  let type = "all";
  let format = "table";

  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--project-dir" && args[i + 1]) {
      projectDir = resolve(args[i + 1]);
      i++;
    } else if (args[i] === "--type" && args[i + 1]) {
      type = args[i + 1];
      i++;
    } else if (args[i] === "--format" && args[i + 1]) {
      format = args[i + 1];
      i++;
    }
  }

  const validTypes = ["drafts", "published", "calendar", "all"];
  if (!validTypes.includes(type)) {
    console.error(`Invalid --type "${type}". Must be one of: ${validTypes.join(", ")}`);
    process.exit(1);
  }

  const validFormats = ["table", "json"];
  if (!validFormats.includes(format)) {
    console.error(`Invalid --format "${format}". Must be one of: ${validFormats.join(", ")}`);
    process.exit(1);
  }

  return { projectDir, type, format };
}

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

function padRight(str, len) {
  const s = String(str ?? "");
  return s.length >= len ? s : s + " ".repeat(len - s.length);
}

function printTable(headers, rows) {
  if (rows.length === 0) {
    console.log("  (none)");
    return;
  }

  const widths = headers.map((h, i) =>
    Math.max(h.length, ...rows.map((r) => String(r[i] ?? "").length))
  );

  const headerLine = headers.map((h, i) => padRight(h, widths[i])).join("  ");
  const separator = widths.map((w) => "-".repeat(w)).join("  ");

  console.log(headerLine);
  console.log(separator);
  for (const row of rows) {
    const line = row.map((val, i) => padRight(String(val ?? ""), widths[i])).join("  ");
    console.log(line);
  }
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

function listDrafts(db) {
  return db
    .prepare(
      `SELECT d.story_id, s.title, s.status, d.version, d.word_count, d.created_at AS updated
       FROM content_drafts d
       LEFT JOIN stories s ON s.story_id = d.story_id
       ORDER BY d.created_at DESC`
    )
    .all();
}

function listPublished(db) {
  return db
    .prepare(
      `SELECT p.story_id, s.title, p.platform, p.status, p.external_url, p.published_at AS updated
       FROM publish_log p
       LEFT JOIN stories s ON s.story_id = p.story_id
       WHERE p.status = 'published'
       ORDER BY p.published_at DESC`
    )
    .all();
}

function listCalendar(db) {
  return db
    .prepare(
      `SELECT c.story_id, c.topic AS title, c.content_type, c.status, c.scheduled_date AS updated
       FROM content_calendar c
       ORDER BY c.scheduled_date ASC`
    )
    .all();
}

function listAll(db) {
  return db
    .prepare(
      `SELECT story_id, title, status, content_type,
              (SELECT MAX(word_count) FROM content_drafts d WHERE d.story_id = stories.story_id) AS word_count,
              updated_at AS updated
       FROM stories
       ORDER BY priority DESC, created_at ASC`
    )
    .all();
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  const { projectDir, type, format } = parseArgs(process.argv);

  let db;
  try {
    db = getDb(projectDir);
  } catch (err) {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  }

  let results;
  let headers;

  switch (type) {
    case "drafts":
      results = listDrafts(db);
      headers = ["Story ID", "Title", "Status", "Version", "Words", "Updated"];
      break;

    case "published":
      results = listPublished(db);
      headers = ["Story ID", "Title", "Platform", "Status", "URL", "Published"];
      break;

    case "calendar":
      results = listCalendar(db);
      headers = ["Story ID", "Title/Topic", "Type", "Status", "Scheduled"];
      break;

    case "all":
    default:
      results = listAll(db);
      headers = ["Story ID", "Title", "Status", "Type", "Words", "Updated"];
      break;
  }

  if (format === "json") {
    console.log(JSON.stringify(results, null, 2));
  } else {
    console.log(`\nContent listing (${type}): ${results.length} items\n`);

    if (type === "drafts") {
      printTable(
        headers,
        results.map((r) => [r.story_id, r.title, r.status, `v${r.version}`, r.word_count, r.updated])
      );
    } else if (type === "published") {
      printTable(
        headers,
        results.map((r) => [r.story_id, r.title, r.platform, r.status, r.external_url || "-", r.updated])
      );
    } else if (type === "calendar") {
      printTable(
        headers,
        results.map((r) => [r.story_id || "-", r.title, r.content_type, r.status, r.updated])
      );
    } else {
      printTable(
        headers,
        results.map((r) => [r.story_id, r.title, r.status, r.content_type || "-", r.word_count ?? "-", r.updated])
      );
    }
  }

  console.log("");
  db.close();
}

main();
