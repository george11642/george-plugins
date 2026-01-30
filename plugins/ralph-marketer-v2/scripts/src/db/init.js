#!/usr/bin/env node

/**
 * Ralph Marketer V2 — Database Initialization
 *
 * Creates all SQLite tables for the content pipeline.
 * Database file: {projectDir}/data/ralph.db
 *
 * Usage:
 *   node scripts/src/db/init.js [--project-dir /path/to/project]
 */

import { createRequire } from "module";
import { mkdirSync, existsSync } from "fs";
import { join, resolve } from "path";

const require = createRequire(import.meta.url);
const Database = require("better-sqlite3");

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
// Table definitions
// ---------------------------------------------------------------------------

const TABLE_SQL = [
  `CREATE TABLE IF NOT EXISTS stories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    story_id TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    content_type TEXT,
    topic TEXT,
    priority INTEGER DEFAULT 0,
    status TEXT DEFAULT 'pending' CHECK(status IN ('pending','in_progress','passed','failed')),
    acceptance_criteria TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
  )`,

  `CREATE TABLE IF NOT EXISTS content_drafts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    story_id TEXT NOT NULL REFERENCES stories(story_id),
    version INTEGER DEFAULT 1,
    content_markdown TEXT,
    content_html TEXT,
    word_count INTEGER DEFAULT 0,
    meta_description TEXT,
    seo_title TEXT,
    tags_json TEXT DEFAULT '[]',
    created_at TEXT DEFAULT (datetime('now'))
  )`,

  `CREATE TABLE IF NOT EXISTS content_reviews (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    draft_id INTEGER NOT NULL REFERENCES content_drafts(id),
    reviewer TEXT NOT NULL,
    passed INTEGER DEFAULT 0,
    feedback TEXT,
    created_at TEXT DEFAULT (datetime('now'))
  )`,

  `CREATE TABLE IF NOT EXISTS publish_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    story_id TEXT NOT NULL,
    platform TEXT NOT NULL,
    external_url TEXT,
    external_id TEXT,
    status TEXT DEFAULT 'pending' CHECK(status IN ('pending','published','failed')),
    error_message TEXT,
    published_at TEXT,
    created_at TEXT DEFAULT (datetime('now'))
  )`,

  `CREATE TABLE IF NOT EXISTS content_calendar (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    story_id TEXT,
    scheduled_date TEXT,
    content_type TEXT,
    topic TEXT,
    status TEXT DEFAULT 'scheduled' CHECK(status IN ('scheduled','published','skipped')),
    created_at TEXT DEFAULT (datetime('now'))
  )`,

  `CREATE TABLE IF NOT EXISTS topics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    slug TEXT UNIQUE,
    description TEXT,
    priority INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now'))
  )`,

  `CREATE TABLE IF NOT EXISTS voice_samples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_text TEXT,
    analysis_json TEXT,
    created_at TEXT DEFAULT (datetime('now'))
  )`,

  `CREATE TABLE IF NOT EXISTS seo_keywords (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    keyword TEXT NOT NULL,
    search_volume_estimate INTEGER,
    difficulty TEXT,
    topic_id INTEGER REFERENCES topics(id),
    created_at TEXT DEFAULT (datetime('now'))
  )`,

  `CREATE TABLE IF NOT EXISTS social_posts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    story_id TEXT REFERENCES stories(story_id),
    platform TEXT NOT NULL,
    content TEXT,
    hashtags_json TEXT DEFAULT '[]',
    scheduled_at TEXT,
    published_at TEXT,
    status TEXT DEFAULT 'pending'
  )`,

  `CREATE TABLE IF NOT EXISTS newsletters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    story_id TEXT REFERENCES stories(story_id),
    subject_line TEXT,
    preview_text TEXT,
    content_html TEXT,
    sent_at TEXT,
    status TEXT DEFAULT 'draft'
  )`,

  `CREATE TABLE IF NOT EXISTS analytics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    story_id TEXT,
    platform TEXT,
    metric_name TEXT NOT NULL,
    metric_value REAL,
    recorded_at TEXT DEFAULT (datetime('now'))
  )`,

  `CREATE TABLE IF NOT EXISTS config_snapshots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    config_json TEXT NOT NULL,
    snapshot_at TEXT DEFAULT (datetime('now'))
  )`,
];

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  const { projectDir } = parseArgs(process.argv);
  const dataDir = join(projectDir, "data");
  const dbPath = join(dataDir, "ralph.db");

  // Ensure data directory exists
  if (!existsSync(dataDir)) {
    mkdirSync(dataDir, { recursive: true });
    console.log(`Created directory: ${dataDir}`);
  }

  console.log(`Initializing database at: ${dbPath}`);

  const db = new Database(dbPath);

  // Enable WAL mode for better concurrent performance
  db.pragma("journal_mode = WAL");

  // Create all tables
  const created = [];
  for (const sql of TABLE_SQL) {
    const match = sql.match(/CREATE TABLE IF NOT EXISTS (\w+)/);
    const tableName = match ? match[1] : "unknown";
    try {
      db.exec(sql);
      created.push(tableName);
    } catch (err) {
      console.error(`  ERROR creating table "${tableName}": ${err.message}`);
    }
  }

  // Print summary
  console.log(`\nDatabase initialized successfully.`);
  console.log(`Tables (${created.length}):`);
  for (const name of created) {
    const row = db.prepare(`SELECT COUNT(*) AS cnt FROM ${name}`).get();
    console.log(`  - ${name} (${row.cnt} rows)`);
  }

  db.close();
}

main();
