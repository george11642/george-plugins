#!/usr/bin/env node

/**
 * Ralph Marketer V2 — Database Seeder
 *
 * Seeds the database with initial data from:
 *   - {projectDir}/.ralph/config.json  -> topics
 *   - {projectDir}/scripts/ralph/prd.json -> stories
 *
 * Idempotent: only inserts when the target table is empty.
 *
 * Usage:
 *   node scripts/src/db/seed.js [--project-dir /path/to/project]
 */

import { readFileSync, existsSync } from "fs";
import { join, resolve } from "path";
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
// JSON file reader with graceful error handling
// ---------------------------------------------------------------------------

function readJsonFile(filePath) {
  if (!existsSync(filePath)) {
    return null;
  }
  try {
    const raw = readFileSync(filePath, "utf-8");
    return JSON.parse(raw);
  } catch (err) {
    console.error(`  Warning: Could not parse ${filePath}: ${err.message}`);
    return null;
  }
}

// ---------------------------------------------------------------------------
// Seeders
// ---------------------------------------------------------------------------

function seedTopics(db, config) {
  const count = db.prepare("SELECT COUNT(*) AS cnt FROM topics").get().cnt;
  if (count > 0) {
    console.log(`  topics: already seeded (${count} rows), skipping.`);
    return 0;
  }

  const topics = config?.content?.topics;
  if (!topics || !Array.isArray(topics) || topics.length === 0) {
    console.log("  topics: no topics found in config.json, skipping.");
    return 0;
  }

  const insert = db.prepare(
    `INSERT INTO topics (name, slug, description, priority) VALUES (?, ?, ?, ?)`
  );

  const insertMany = db.transaction((items) => {
    let inserted = 0;
    for (const topic of items) {
      const name =
        typeof topic === "string" ? topic : topic.name || topic.title || "";
      if (!name) continue;

      const slug =
        topic.slug ||
        name
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, "-")
          .replace(/^-|-$/g, "");
      const description = topic.description || null;
      const priority = topic.priority ?? 0;

      insert.run(name, slug, description, priority);
      inserted++;
    }
    return inserted;
  });

  const inserted = insertMany(topics);
  console.log(`  topics: seeded ${inserted} rows.`);
  return inserted;
}

function seedStories(db, prd) {
  const count = db.prepare("SELECT COUNT(*) AS cnt FROM stories").get().cnt;
  if (count > 0) {
    console.log(`  stories: already seeded (${count} rows), skipping.`);
    return 0;
  }

  // Support both { stories: [...] } and { sprints: [{ stories: [...] }] } shapes
  let stories = [];

  if (Array.isArray(prd?.stories)) {
    stories = prd.stories;
  } else if (Array.isArray(prd?.sprints)) {
    for (const sprint of prd.sprints) {
      if (Array.isArray(sprint?.stories)) {
        stories.push(...sprint.stories);
      }
    }
  }

  if (stories.length === 0) {
    console.log("  stories: no stories found in prd.json, skipping.");
    return 0;
  }

  const insert = db.prepare(
    `INSERT INTO stories (story_id, title, description, content_type, topic, priority, status, acceptance_criteria)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
  );

  const insertMany = db.transaction((items) => {
    let inserted = 0;
    for (const story of items) {
      const storyId = story.story_id || story.id || `STORY-${String(inserted + 1).padStart(3, "0")}`;
      const title = story.title || "Untitled";
      const description = story.description || null;
      const contentType = story.content_type || story.type || null;
      const topic = story.topic || null;
      const priority = story.priority ?? 0;
      const status = story.passes === true ? "passed" : "pending";

      let acceptance = null;
      if (story.acceptance_criteria) {
        acceptance =
          typeof story.acceptance_criteria === "string"
            ? story.acceptance_criteria
            : JSON.stringify(story.acceptance_criteria);
      }

      insert.run(
        storyId,
        title,
        description,
        contentType,
        topic,
        priority,
        status,
        acceptance
      );
      inserted++;
    }
    return inserted;
  });

  const inserted = insertMany(stories);
  console.log(`  stories: seeded ${inserted} rows.`);
  return inserted;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  const { projectDir } = parseArgs(process.argv);

  console.log(`Seeding database for project: ${projectDir}`);

  const db = getDb(projectDir);

  // Read source files
  const configPath = join(projectDir, ".ralph", "config.json");
  const prdPath = join(projectDir, "scripts", "ralph", "prd.json");

  const config = readJsonFile(configPath);
  const prd = readJsonFile(prdPath);

  if (!config && !prd) {
    console.log(
      "\nNo config.json or prd.json found. Nothing to seed."
    );
    console.log(`  Looked for: ${configPath}`);
    console.log(`  Looked for: ${prdPath}`);
    db.close();
    return;
  }

  console.log("\nSeeding tables:");

  if (config) {
    seedTopics(db, config);
  } else {
    console.log(`  topics: config.json not found at ${configPath}, skipping.`);
  }

  if (prd) {
    seedStories(db, prd);
  } else {
    console.log(`  stories: prd.json not found at ${prdPath}, skipping.`);
  }

  console.log("\nSeed complete.");
  db.close();
}

main();
