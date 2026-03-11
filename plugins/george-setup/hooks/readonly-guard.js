#!/usr/bin/env node

// PreToolUse hook: Block file modifications when readonly mode is active
const fs = require('fs');
const path = require('path');

const BEHAVIOR_PATH = path.join(process.env.HOME, '.claude', 'behavior.json');

function main() {
  let behavior;
  try {
    behavior = JSON.parse(fs.readFileSync(BEHAVIOR_PATH, 'utf8'));
  } catch {
    return; // No behavior.json = no restrictions
  }

  if (!behavior.toggles?.readonly) return;

  // Read hook input from stdin
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

  const tool = hookData.tool_name || '';
  const blockedTools = ['Write', 'Edit', 'NotebookEdit'];

  // Also block destructive Bash commands
  if (tool === 'Bash') {
    const cmd = hookData.tool_input?.command || '';
    const destructivePatterns = /\b(rm|mv|cp|git (push|commit|reset|checkout)|chmod|chown|kill|pkill)\b/;
    if (destructivePatterns.test(cmd)) {
      console.log(JSON.stringify({
        decision: 'block',
        reason: 'Readonly mode is active. Destructive Bash commands are blocked. Use /mode autonomous to disable readonly.'
      }));
      return;
    }
    return; // Non-destructive bash is fine in readonly
  }

  if (blockedTools.includes(tool)) {
    console.log(JSON.stringify({
      decision: 'block',
      reason: `Readonly mode is active. ${tool} is blocked. Use /mode autonomous to disable readonly.`
    }));
    return;
  }
}

try {
  main();
} catch (err) {
  try {
    const fs2 = require('fs');
    const path2 = require('path');
    fs2.appendFileSync(path2.join(process.env.HOME, '.claude', 'hook-errors.log'),
      `[${new Date().toISOString()}] [readonly-guard.js] ${err?.stack || err}\n`);
  } catch {}
}
