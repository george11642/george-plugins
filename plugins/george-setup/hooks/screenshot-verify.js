#!/usr/bin/env node

// Stop hook: Remind to take browser screenshots when UI files were touched
// and screenshot_verify toggle is ON.
const fs = require('fs');
const path = require('path');

const BEHAVIOR_PATH = path.join(process.env.HOME, '.claude', 'behavior.json');

// File patterns that indicate UI work
const UI_PATTERNS = [
  /\.(tsx|jsx)$/,
  /\.(css|scss|sass|less)$/,
  /tailwind/,
  /\.module\.\w+$/,
  /components?\//i,
  /pages?\//i,
  /app\//i,
  /layouts?\//i,
];

// Timeout guard: exit silently if stdin doesn't close within 3s
const stdinTimeout = setTimeout(() => {
  run(null);
  process.exit(0);
}, 3000);

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  clearTimeout(stdinTimeout);
  let stdinData = null;
  try {
    stdinData = JSON.parse(input);
  } catch {}
  run(stdinData);
});

function run(stdinData) {
  try {
    _run(stdinData);
  } catch (err) {
    try {
      fs.appendFileSync(path.join(process.env.HOME, '.claude', 'hook-errors.log'),
        `[${new Date().toISOString()}] [screenshot-verify.js] ${err?.stack || err}\n`);
    } catch {}
  }
}

function _run(stdinData) {
  let behavior;
  try {
    behavior = JSON.parse(fs.readFileSync(BEHAVIOR_PATH, 'utf8'));
  } catch {
    return;
  }

  if (!behavior.toggles?.screenshot_verify) return;

  // Check tool_use history from stdin for Write/Edit calls on UI files
  const toolUses = extractToolUses(stdinData);
  const uiFilesTouched = [];

  for (const tu of toolUses) {
    const toolName = tu.name || '';
    if (toolName !== 'Write' && toolName !== 'Edit') continue;

    const filePath = tu.input?.file_path || '';
    if (UI_PATTERNS.some(p => p.test(filePath))) {
      uiFilesTouched.push(filePath);
    }
  }

  if (uiFilesTouched.length > 0) {
    const fileList = [...new Set(uiFilesTouched)].slice(0, 5).map(f => path.basename(f)).join(', ');
    console.log(
      `SCREENSHOT VERIFY is ON: UI files were modified (${fileList}). ` +
      'Take a browser screenshot at 1440px and 375px widths to visually verify the changes ' +
      'using the superpowers-chrome MCP browser tool.'
    );
  }
}

/**
 * Extract tool_use blocks from Stop hook stdin data.
 * The Stop hook receives the conversation so far.
 */
function extractToolUses(stdinData) {
  const results = [];
  if (!stdinData) return results;

  // Stop hook stdin contains stop_hook_active, tool_calls_this_turn, etc.
  // Try multiple possible shapes
  const messages = stdinData.messages || stdinData.conversation || [];
  if (Array.isArray(messages)) {
    for (const msg of messages) {
      const content = msg.message?.content || msg.content;
      if (!Array.isArray(content)) continue;
      for (const block of content) {
        if (block.type === 'tool_use') {
          results.push(block);
        }
      }
    }
  }

  // Also check tool_results or recent_tool_uses if present
  const recentTools = stdinData.tool_uses || stdinData.recent_tool_uses || [];
  if (Array.isArray(recentTools)) {
    for (const tu of recentTools) {
      results.push(tu);
    }
  }

  return results;
}
