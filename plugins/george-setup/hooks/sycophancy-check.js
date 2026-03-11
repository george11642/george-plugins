#!/usr/bin/env node

// PostToolUse hook: Detect rubber-stamp reviews from multiple agents
const fs = require('fs');
const path = require('path');
const os = require('os');

const { detectSycophancy } = require('./lib/sycophancy-detector');

const PPID = process.ppid || 'unknown';
const BUFFER_PATH = `/tmp/claude-agent-reviews-${PPID}.json`;
const TELEMETRY_PATH = path.join(os.homedir(), '.claude', 'telemetry.jsonl');
const REVIEW_THRESHOLD = 3;
const SIMILARITY_THRESHOLD = 0.7;

const logTelemetry = (data) => {
  try {
    fs.appendFileSync(TELEMETRY_PATH,
      JSON.stringify({ ts: new Date().toISOString(), ...data }) + '\n');
  } catch {}
};

/**
 * Extract text content from the PostToolUse hook input.
 * The stdin JSON contains tool_result with the agent's response.
 */
function extractAgentText(hookData) {
  const result = hookData.tool_result;
  if (!result) return null;

  // tool_result can be a string or structured content
  if (typeof result === 'string') return result;

  // If it's an array of content blocks, extract text
  if (Array.isArray(result)) {
    return result
      .filter(b => b.type === 'text' || typeof b === 'string')
      .map(b => typeof b === 'string' ? b : b.text || '')
      .join('\n');
  }

  // If it has a text property
  if (result.text) return result.text;

  // If it has content array
  if (result.content && Array.isArray(result.content)) {
    return result.content
      .filter(b => b.type === 'text' || typeof b === 'string')
      .map(b => typeof b === 'string' ? b : b.text || '')
      .join('\n');
  }

  // Fallback: stringify
  return JSON.stringify(result);
}

function loadBuffer() {
  try {
    return JSON.parse(fs.readFileSync(BUFFER_PATH, 'utf8'));
  } catch {
    return { reviews: [], created: Date.now() };
  }
}

function saveBuffer(buffer) {
  try {
    fs.writeFileSync(BUFFER_PATH, JSON.stringify(buffer, null, 2));
  } catch {}
}

function clearBuffer() {
  try {
    fs.unlinkSync(BUFFER_PATH);
  } catch {}
}

function main() {
  let input = '';
  try {
    input = fs.readFileSync(0, 'utf8');
  } catch {
    return;
  }

  let hookData;
  try {
    hookData = JSON.parse(input);
  } catch {
    return;
  }

  // Only activate for Agent tool results
  if (hookData.tool_name !== 'Agent') return;

  const text = extractAgentText(hookData);
  if (!text || text.length < 50) return; // Skip trivially short results

  // Buffer this review
  const buffer = loadBuffer();

  // Auto-expire buffer after 10 minutes of inactivity
  if (buffer.created && Date.now() - buffer.created > 600000) {
    buffer.reviews = [];
    buffer.created = Date.now();
  }

  buffer.reviews.push(text);
  saveBuffer(buffer);

  // Only run check when we have enough reviews
  if (buffer.reviews.length < REVIEW_THRESHOLD) return;

  const result = detectSycophancy(buffer.reviews, SIMILARITY_THRESHOLD);

  logTelemetry({
    event: 'sycophancy_check',
    review_count: buffer.reviews.length,
    similarity: result.similarity,
    is_sycophantic: result.isSycophantic,
  });

  if (result.isSycophantic) {
    const pct = (result.similarity * 100).toFixed(0);
    console.log(
      `\u26a0 Anti-sycophancy alert: Agent reviews show ${pct}% word overlap ` +
      `(threshold: ${(SIMILARITY_THRESHOLD * 100).toFixed(0)}%). ` +
      `Reviews may be rubber-stamped. Consider re-running with explicit ` +
      `instruction to be critical and find issues.`
    );
  }

  // Reset buffer after check
  clearBuffer();
}

try {
  main();
} catch (err) {
  try {
    const fs2 = require('fs');
    const path2 = require('path');
    fs2.appendFileSync(path2.join(process.env.HOME, '.claude', 'hook-errors.log'),
      `[${new Date().toISOString()}] [sycophancy-check.js] ${err?.stack || err}\n`);
  } catch {}
}
