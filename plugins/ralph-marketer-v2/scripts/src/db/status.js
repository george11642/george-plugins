#!/usr/bin/env node

/**
 * Ralph Marketer V2 — Pipeline Status
 *
 * Prints a summary of the content pipeline:
 *   - Story counts by status
 *   - Recent publish log entries
 *   - Upcoming content calendar items
 *   - Drafts currently in progress
 *
 * Usage:
 *   node scripts/src/db/status.js [--project-dir /path/to/project]
 */

import { resolve } from "path";
import { getDb } from "./query.js";

// ---------------------------------------------------------------------------
// CLI argument parsing
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const args = argv.slice(2);
  let projectDir = process.cwd();

  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--project-dir" && args[i + 1]) {
      projectDir = resolve(args[i + 1]);
      i++;
    }
  }

  return { projectDir };
}

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

function padRight(str, len) {
  const s = String(str ?? "");
  return s.length >= len ? s : s + " ".repeat(len - s.length);
}

function padLeft(str, len) {
  const s = String(str ?? "");
  return s.length >= len ? s : " ".repeat(len - s.length) + s;
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

  console.log(`  ${headerLine}`);
  console.log(`  ${separator}`);
  for (const row of rows) {
    const line = row.map((val, i) => padRight(String(val ?? ""), widths[i])).join("  ");
    console.log(`  ${line}`);
  }
}

// ---------------------------------------------------------------------------
// Status sections
// ---------------------------------------------------------------------------

function printStoryStatus(db) {
  console.log("\n=== Story Pipeline ===\n");

  const total = db.prepare("SELECT COUNT(*) AS cnt FROM stories").get().cnt;
  const byStatus = db
    .prepare(
      "SELECT status, COUNT(*) AS cnt FROM stories GROUP BY status ORDER BY status"
    )
    .all();

  console.log(`  Total stories: ${total}`);
  for (const row of byStatus) {
    console.log(`    ${row.status}: ${row.cnt}`);
  }

  if (total === 0) return;

  // In-progress stories
  const inProgress = db
    .prepare(
      `SELECT story_id, title, content_type, updated_at
       FROM stories WHERE status = 'in_progress'
       ORDER BY priority DESC, updated_at DESC`
    )
    .all();

  if (inProgress.length > 0) {
    console.log(`\n  In Progress (${inProgress.length}):`);
    printTable(
      ["Story ID", "Title", "Type", "Updated"],
      inProgress.map((s) => [s.story_id, s.title, s.content_type, s.updated_at])
    );
  }
}

function printDraftStatus(db) {
  console.log("\n=== Drafts ===\n");

  const drafts = db
    .prepare(
      `SELECT d.story_id, s.title, d.version, d.word_count, d.created_at
       FROM content_drafts d
       LEFT JOIN stories s ON s.story_id = d.story_id
       ORDER BY d.created_at DESC
       LIMIT 10`
    )
    .all();

  if (drafts.length === 0) {
    console.log("  No drafts yet.");
    return;
  }

  printTable(
    ["Story ID", "Title", "Version", "Words", "Created"],
    drafts.map((d) => [d.story_id, d.title, `v${d.version}`, d.word_count, d.created_at])
  );
}

function printPublishLog(db) {
  console.log("\n=== Recent Publish Log ===\n");

  const logs = db
    .prepare(
      `SELECT story_id, platform, status, external_url, published_at, created_at
       FROM publish_log
       ORDER BY created_at DESC
       LIMIT 10`
    )
    .all();

  if (logs.length === 0) {
    console.log("  No publish log entries yet.");
    return;
  }

  printTable(
    ["Story ID", "Platform", "Status", "URL", "Published At"],
    logs.map((l) => [
      l.story_id,
      l.platform,
      l.status,
      l.external_url || "-",
      l.published_at || "-",
    ])
  );
}

function printCalendar(db) {
  console.log("\n=== Content Calendar (Upcoming) ===\n");

  const upcoming = db
    .prepare(
      `SELECT story_id, scheduled_date, content_type, topic, status
       FROM content_calendar
       WHERE status = 'scheduled'
       ORDER BY scheduled_date ASC
       LIMIT 10`
    )
    .all();

  if (upcoming.length === 0) {
    console.log("  No upcoming scheduled items.");
    return;
  }

  printTable(
    ["Story ID", "Scheduled", "Type", "Topic", "Status"],
    upcoming.map((c) => [
      c.story_id || "-",
      c.scheduled_date,
      c.content_type,
      c.topic,
      c.status,
    ])
  );
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  const { projectDir } = parseArgs(process.argv);

  let db;
  try {
    db = getDb(projectDir);
  } catch (err) {
    console.error(`Error: ${err.message}`);
    console.error("Run 'npm run db:init' to create the database first.");
    process.exit(1);
  }

  console.log("Ralph Marketer V2 — Pipeline Status");
  console.log(`Project: ${projectDir}`);

  printStoryStatus(db);
  printDraftStatus(db);
  printPublishLog(db);
  printCalendar(db);

  console.log("");
  db.close();
}

main();
