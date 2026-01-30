/**
 * Ralph Marketer V2 — Database Query Utilities
 *
 * Shared module for accessing the Ralph SQLite database.
 *
 * Usage:
 *   import { getDb, getStories, getDrafts, getPublishLog, updateStoryStatus } from './query.js';
 */

import { createRequire } from "module";
import { join } from "path";
import { existsSync } from "fs";

const require = createRequire(import.meta.url);
const Database = require("better-sqlite3");

/**
 * Open (or create) the Ralph SQLite database for the given project directory.
 *
 * @param {string} projectDir - Absolute path to the project root.
 * @returns {import('better-sqlite3').Database} The database instance.
 */
export function getDb(projectDir) {
  const dbPath = join(projectDir, "data", "ralph.db");

  if (!existsSync(dbPath)) {
    throw new Error(
      `Database not found at ${dbPath}. Run "npm run db:init" first.`
    );
  }

  const db = new Database(dbPath);
  db.pragma("journal_mode = WAL");
  return db;
}

/**
 * Retrieve stories, optionally filtered by status.
 *
 * @param {import('better-sqlite3').Database} db
 * @param {string} [status] - Filter by status (pending, in_progress, passed, failed).
 * @returns {Array<Object>}
 */
export function getStories(db, status) {
  if (status) {
    return db
      .prepare(
        `SELECT * FROM stories WHERE status = ? ORDER BY priority DESC, created_at ASC`
      )
      .all(status);
  }
  return db
    .prepare(`SELECT * FROM stories ORDER BY priority DESC, created_at ASC`)
    .all();
}

/**
 * Retrieve content drafts, optionally filtered by story_id.
 *
 * @param {import('better-sqlite3').Database} db
 * @param {string} [storyId] - Filter by story_id.
 * @returns {Array<Object>}
 */
export function getDrafts(db, storyId) {
  if (storyId) {
    return db
      .prepare(
        `SELECT * FROM content_drafts WHERE story_id = ? ORDER BY version DESC`
      )
      .all(storyId);
  }
  return db
    .prepare(`SELECT * FROM content_drafts ORDER BY created_at DESC`)
    .all();
}

/**
 * Retrieve recent publish log entries.
 *
 * @param {import('better-sqlite3').Database} db
 * @param {number} [limit=20] - Maximum number of entries to return.
 * @returns {Array<Object>}
 */
export function getPublishLog(db, limit = 20) {
  return db
    .prepare(`SELECT * FROM publish_log ORDER BY created_at DESC LIMIT ?`)
    .all(limit);
}

/**
 * Update the status of a story by its story_id.
 *
 * @param {import('better-sqlite3').Database} db
 * @param {string} storyId - The story_id to update.
 * @param {string} status - New status (pending, in_progress, passed, failed).
 * @returns {{ changes: number }} Number of rows updated.
 */
export function updateStoryStatus(db, storyId, status) {
  const validStatuses = ["pending", "in_progress", "passed", "failed"];
  if (!validStatuses.includes(status)) {
    throw new Error(
      `Invalid status "${status}". Must be one of: ${validStatuses.join(", ")}`
    );
  }

  const result = db
    .prepare(
      `UPDATE stories SET status = ?, updated_at = datetime('now') WHERE story_id = ?`
    )
    .run(status, storyId);

  if (result.changes === 0) {
    throw new Error(`Story "${storyId}" not found.`);
  }

  return { changes: result.changes };
}
