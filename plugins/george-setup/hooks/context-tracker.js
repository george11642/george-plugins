#!/usr/bin/env node

// PostToolUse hook: Track context budget and inject goal-anchoring reminders
const fs = require('fs');
const path = require('path');

const BEHAVIOR_PATH = path.join(process.env.HOME, '.claude', 'behavior.json');
const COUNTER_PATH = path.join(process.env.HOME, '.claude', 'tool-call-counter.json');
const ANCHOR_INTERVAL = 50;

function main() {
  // Use a separate file for tool_call_count to avoid racing with other
  // hooks/processes that read-modify-write behavior.json
  let counter;
  try {
    counter = JSON.parse(fs.readFileSync(COUNTER_PATH, 'utf8'));
  } catch {
    counter = { tool_call_count: 0 };
  }

  counter.tool_call_count = (counter.tool_call_count || 0) + 1;
  fs.writeFileSync(COUNTER_PATH, JSON.stringify(counter, null, 2));

  // Goal anchoring every N calls — read behavior.json read-only for display
  if (counter.tool_call_count % ANCHOR_INTERVAL === 0) {
    let behavior = {};
    try {
      behavior = JSON.parse(fs.readFileSync(BEHAVIOR_PATH, 'utf8'));
    } catch {}

    const parts = [
      `\n--- GOAL ANCHOR (${counter.tool_call_count} tool calls) ---`,
      `Domain: ${behavior.active_domain || 'unset'}`,
      `Mode: autonomy=${behavior.autonomy || 'unset'}`,
    ];

    // Check git for recent activity
    try {
      const { execFileSync } = require('child_process');
      const status = execFileSync('git', ['diff', '--name-only', 'HEAD'], { encoding: 'utf8', timeout: 5000 }).trim();
      if (status) {
        parts.push(`Files changed since last commit: ${status.split('\n').length}`);
      }
    } catch {}

    parts.push('Review: Are you still on track with the original task?');
    parts.push('--- END ANCHOR ---');
    console.log(parts.join('\n'));
  }
}

try {
  main();
} catch (err) {
  try {
    const fs2 = require('fs');
    const path2 = require('path');
    fs2.appendFileSync(path2.join(process.env.HOME, '.claude', 'hook-errors.log'),
      `[${new Date().toISOString()}] [context-tracker.js] ${err?.stack || err}\n`);
  } catch {}
}
