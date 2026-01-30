#!/usr/bin/env node

/**
 * Publisher Router
 * Main entry point for the publishing system.
 *
 * CLI: node scripts/src/publish/index.js <content-file> [platform] [--dry-run]
 *
 * Reads .ralph/config.json for publishing targets, parses the content file
 * (markdown with YAML frontmatter), publishes to primary target first,
 * then cross-posts to all configured targets.
 *
 * @typedef {object} ContentPayload
 * @property {string} title
 * @property {string} slug
 * @property {string} content_markdown
 * @property {string} content_html
 * @property {string} excerpt
 * @property {string} meta_description
 * @property {string} seo_title
 * @property {string[]} tags
 * @property {string} category_slug
 * @property {string} [featured_image_url]
 * @property {string} [author_name]
 */

import { readFile } from 'fs/promises';
import { join } from 'path';
import { marked } from 'marked';

import { publishToSupabase } from './supabase.js';
import { publishToMedium } from './medium.js';
import { publishToDevto } from './devto.js';
import { publishToMarkdown } from './markdown-files.js';
import { publishToMdx } from './nextjs-mdx.js';

// ── Publisher Registry ──────────────────────────────────────────────────────

const PUBLISHERS = {
  supabase: publishToSupabase,
  medium: publishToMedium,
  devto: publishToDevto,
  'markdown-files': publishToMarkdown,
  'nextjs-mdx': publishToMdx,
};

// ── Frontmatter Parser ──────────────────────────────────────────────────────

/**
 * Parse YAML-style frontmatter from a markdown string.
 * Handles basic YAML: scalars, arrays (both inline and block), and quoted strings.
 *
 * @param {string} raw - Full file content with frontmatter
 * @returns {{ meta: Record<string, unknown>, body: string }}
 */
function parseFrontmatter(raw) {
  const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n([\s\S]*)$/);
  if (!match) {
    return { meta: {}, body: raw };
  }

  const [, yamlBlock, body] = match;
  const meta = {};
  let currentKey = null;
  let currentArray = null;

  for (const line of yamlBlock.split('\n')) {
    // Block array item (  - value)
    const arrayItemMatch = line.match(/^\s+-\s+(.+)$/);
    if (arrayItemMatch && currentKey) {
      if (!currentArray) currentArray = [];
      let val = arrayItemMatch[1].trim();
      // Strip surrounding quotes
      if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
        val = val.slice(1, -1);
      }
      currentArray.push(val);
      meta[currentKey] = currentArray;
      continue;
    }

    // Key: value line
    const kvMatch = line.match(/^([a-zA-Z_][a-zA-Z0-9_-]*)\s*:\s*(.*)$/);
    if (kvMatch) {
      // Flush any pending array
      currentArray = null;

      const key = kvMatch[1].trim();
      let value = kvMatch[2].trim();
      currentKey = key;

      if (value === '') {
        // Could be start of a block array or empty value
        meta[key] = '';
        continue;
      }

      // Inline array: [a, b, c]
      if (value.startsWith('[') && value.endsWith(']')) {
        const inner = value.slice(1, -1);
        meta[key] = inner
          .split(',')
          .map((s) => s.trim())
          .filter(Boolean)
          .map((s) => {
            if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
              return s.slice(1, -1);
            }
            return s;
          });
        continue;
      }

      // Strip surrounding quotes from scalar values
      if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
        value = value.slice(1, -1);
      }

      meta[key] = value;
    }
  }

  return { meta, body: body.trim() };
}

/**
 * Build a ContentPayload from parsed frontmatter and markdown body.
 *
 * @param {Record<string, unknown>} meta - Parsed frontmatter fields
 * @param {string} body - Markdown body content
 * @returns {ContentPayload}
 */
function buildContentPayload(meta, body) {
  const title = String(meta.title || 'Untitled');
  const slug = String(meta.slug || title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, ''));

  let tags = meta.tags || [];
  if (typeof tags === 'string') {
    tags = tags.split(',').map((t) => t.trim()).filter(Boolean);
  }

  return {
    title,
    slug,
    content_markdown: body,
    content_html: marked(body),
    excerpt: String(meta.excerpt || meta.description || body.slice(0, 200).replace(/\n/g, ' ') + '...'),
    meta_description: String(meta.meta_description || meta.description || ''),
    seo_title: String(meta.seo_title || meta.title || title),
    tags: Array.isArray(tags) ? tags : [tags],
    category_slug: String(meta.category_slug || meta.category || ''),
    featured_image_url: meta.featured_image_url || meta.image || meta.featured_image || undefined,
    author_name: meta.author_name || meta.author || undefined,
  };
}

// ── Config Loader ───────────────────────────────────────────────────────────

/**
 * Load .ralph/config.json from the project directory.
 * @returns {Promise<object>}
 */
async function loadConfig() {
  const configPath = join(process.cwd(), '.ralph', 'config.json');
  try {
    const raw = await readFile(configPath, 'utf-8');
    return JSON.parse(raw);
  } catch (err) {
    if (err.code === 'ENOENT') {
      console.log('[router] No .ralph/config.json found, using defaults');
      return {
        publishing: {
          primary: 'markdown-files',
          crosspost: [],
          fallback: 'markdown-files',
        },
      };
    }
    throw err;
  }
}

// ── Database Logger ─────────────────────────────────────────────────────────

/**
 * Log a publish result to the SQLite publish_log table.
 * Fails silently if the database is not available.
 *
 * @param {string} slug
 * @param {string} platform
 * @param {boolean} success
 * @param {string} [url]
 * @param {string} [error]
 */
async function logToDatabase(slug, platform, success, url, error) {
  try {
    const Database = (await import('better-sqlite3')).default;
    const dbPath = join(process.cwd(), '.ralph', 'ralph.db');
    const db = new Database(dbPath);

    // Create table if it doesn't exist
    db.exec(`
      CREATE TABLE IF NOT EXISTS publish_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        slug TEXT NOT NULL,
        platform TEXT NOT NULL,
        success INTEGER NOT NULL DEFAULT 0,
        url TEXT,
        error TEXT,
        published_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    `);

    db.prepare(
      'INSERT INTO publish_log (slug, platform, success, url, error) VALUES (?, ?, ?, ?, ?)'
    ).run(slug, platform, success ? 1 : 0, url || null, error || null);

    db.close();
  } catch (dbErr) {
    // Non-fatal: we still want publishing to succeed even if logging fails
    console.log(`[router] Warning: could not log to database: ${dbErr.message}`);
  }
}

// ── Resolve Publisher ───────────────────────────────────────────────────────

/**
 * Get a publisher function by platform name.
 * @param {string} platform
 * @returns {Function|null}
 */
function getPublisher(platform) {
  return PUBLISHERS[platform] || null;
}

// ── Main Router Logic ───────────────────────────────────────────────────────

/**
 * Publish content following the configured routing:
 * primary -> crosspost targets (with canonical URL) -> fallback on failure.
 *
 * @param {ContentPayload} content
 * @param {object} config
 * @param {object} options
 * @param {boolean} [options.dryRun]
 * @param {string} [options.platformOverride] - Publish only to this platform
 * @returns {Promise<{primary: object|null, crosspost: object[], fallback: object|null}>}
 */
async function routePublish(content, config, options = {}) {
  const { dryRun = false, platformOverride } = options;
  const publishing = config.publishing || {};

  const results = {
    primary: null,
    crosspost: [],
    fallback: null,
  };

  // If a specific platform override is given, publish only there
  if (platformOverride) {
    const publisher = getPublisher(platformOverride);
    if (!publisher) {
      console.log(`[router] Unknown platform: ${platformOverride}`);
      results.primary = { platform: platformOverride, success: false, error: `Unknown platform: ${platformOverride}` };
      return results;
    }

    if (dryRun) {
      console.log(`[router] DRY RUN: Would publish "${content.title}" to ${platformOverride}`);
      results.primary = { platform: platformOverride, success: true, dryRun: true };
      return results;
    }

    console.log(`[router] Publishing to ${platformOverride} (override)...`);
    const result = await publisher(content, config);
    results.primary = { platform: platformOverride, ...result };
    await logToDatabase(content.slug, platformOverride, result.success, result.url || result.path, result.error);
    return results;
  }

  // Step 1: Publish to primary target
  const primaryPlatform = publishing.primary || 'markdown-files';
  const primaryPublisher = getPublisher(primaryPlatform);

  if (!primaryPublisher) {
    console.log(`[router] Unknown primary platform: ${primaryPlatform}`);
    results.primary = { platform: primaryPlatform, success: false, error: `Unknown platform: ${primaryPlatform}` };
  } else if (dryRun) {
    console.log(`[router] DRY RUN: Would publish "${content.title}" to primary: ${primaryPlatform}`);
    results.primary = { platform: primaryPlatform, success: true, dryRun: true };
  } else {
    console.log(`[router] Publishing to primary: ${primaryPlatform}...`);
    const primaryResult = await primaryPublisher(content, config);
    results.primary = { platform: primaryPlatform, ...primaryResult };
    await logToDatabase(content.slug, primaryPlatform, primaryResult.success, primaryResult.url || primaryResult.path, primaryResult.error);
  }

  // Step 2: If primary failed, try fallback
  if (results.primary && !results.primary.success && !dryRun) {
    const fallbackPlatform = publishing.fallback || 'markdown-files';
    if (fallbackPlatform !== primaryPlatform) {
      const fallbackPublisher = getPublisher(fallbackPlatform);
      if (fallbackPublisher) {
        console.log(`[router] Primary failed, trying fallback: ${fallbackPlatform}...`);
        const fallbackResult = await fallbackPublisher(content, config);
        results.fallback = { platform: fallbackPlatform, ...fallbackResult };
        await logToDatabase(content.slug, fallbackPlatform, fallbackResult.success, fallbackResult.url || fallbackResult.path, fallbackResult.error);
      }
    }
  }

  // Step 3: Cross-post to configured targets (only if primary or fallback succeeded)
  const primarySucceeded = results.primary?.success;
  const fallbackSucceeded = results.fallback?.success;

  if (primarySucceeded || fallbackSucceeded) {
    const canonicalUrl = results.primary?.url || results.fallback?.url || results.fallback?.path;
    const crosspostTargets = publishing.crosspost || [];

    for (const target of crosspostTargets) {
      const crossPublisher = getPublisher(target);
      if (!crossPublisher) {
        console.log(`[router] Unknown crosspost target: ${target}, skipping`);
        results.crosspost.push({ platform: target, success: false, error: `Unknown platform: ${target}` });
        continue;
      }

      if (dryRun) {
        console.log(`[router] DRY RUN: Would cross-post "${content.title}" to ${target}`);
        results.crosspost.push({ platform: target, success: true, dryRun: true });
        continue;
      }

      console.log(`[router] Cross-posting to ${target}...`);
      const crossResult = await crossPublisher(content, config, canonicalUrl);
      results.crosspost.push({ platform: target, ...crossResult });
      await logToDatabase(content.slug, target, crossResult.success, crossResult.url || crossResult.path, crossResult.error);
    }
  }

  return results;
}

// ── CLI ─────────────────────────────────────────────────────────────────────

/**
 * Print a summary of publish results.
 * @param {object} results
 */
function printSummary(results) {
  console.log('\n========== PUBLISH RESULTS ==========');

  if (results.primary) {
    const p = results.primary;
    const status = p.dryRun ? 'DRY RUN' : p.success ? 'OK' : 'FAILED';
    console.log(`  Primary [${p.platform}]: ${status}${p.url ? ` -> ${p.url}` : ''}${p.path ? ` -> ${p.path}` : ''}${p.error ? ` (${p.error})` : ''}`);
  }

  if (results.fallback) {
    const f = results.fallback;
    const status = f.success ? 'OK' : 'FAILED';
    console.log(`  Fallback [${f.platform}]: ${status}${f.url ? ` -> ${f.url}` : ''}${f.path ? ` -> ${f.path}` : ''}${f.error ? ` (${f.error})` : ''}`);
  }

  for (const c of results.crosspost) {
    const status = c.dryRun ? 'DRY RUN' : c.success ? 'OK' : 'FAILED';
    console.log(`  Crosspost [${c.platform}]: ${status}${c.url ? ` -> ${c.url}` : ''}${c.path ? ` -> ${c.path}` : ''}${c.error ? ` (${c.error})` : ''}`);
  }

  console.log('=====================================\n');
}

async function main() {
  const args = process.argv.slice(2);

  // Parse flags
  const dryRun = args.includes('--dry-run');
  const positionalArgs = args.filter((a) => !a.startsWith('--'));

  if (positionalArgs.length === 0) {
    console.error('Usage: node scripts/src/publish/index.js <content-file> [platform] [--dry-run]');
    console.error('');
    console.error('Arguments:');
    console.error('  content-file   Path to markdown file with YAML frontmatter');
    console.error('  platform       Optional: publish only to this platform');
    console.error('                 Available: supabase, medium, devto, markdown-files, nextjs-mdx');
    console.error('');
    console.error('Flags:');
    console.error('  --dry-run      Preview what would be published without actually doing it');
    process.exit(1);
  }

  const contentFilePath = positionalArgs[0];
  const platformOverride = positionalArgs[1] || null;

  // Load content file
  let rawContent;
  try {
    rawContent = await readFile(contentFilePath, 'utf-8');
  } catch (err) {
    console.error(`[router] Error reading content file: ${err.message}`);
    process.exit(1);
  }

  // Parse frontmatter + body
  const { meta, body } = parseFrontmatter(rawContent);
  if (!body) {
    console.error('[router] Error: content file has no body content after frontmatter');
    process.exit(1);
  }

  const content = buildContentPayload(meta, body);
  console.log(`[router] Parsed content: "${content.title}" (slug: ${content.slug})`);

  if (dryRun) {
    console.log('[router] DRY RUN mode enabled');
  }

  // Load config
  const config = await loadConfig();

  // Route and publish
  const results = await routePublish(content, config, {
    dryRun,
    platformOverride,
  });

  // Print summary
  printSummary(results);

  // Exit with error if everything failed
  const anySuccess =
    results.primary?.success ||
    results.fallback?.success ||
    results.crosspost.some((c) => c.success);

  if (!anySuccess && !dryRun) {
    process.exit(1);
  }
}

// Run if called directly as CLI
main().catch((err) => {
  console.error(`[router] Fatal error: ${err.message}`);
  process.exit(1);
});

// Named exports for programmatic use
export { routePublish, parseFrontmatter, buildContentPayload, loadConfig, PUBLISHERS };
