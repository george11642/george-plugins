#!/usr/bin/env node

// PostToolUse hook: Self-healing on tool failures
const fs = require('fs');
const path = require('path');
const os = require('os');

const logTelemetry = (data) => { try { fs.appendFileSync(path.join(os.homedir(), '.claude/telemetry.jsonl'), JSON.stringify({ts: new Date().toISOString(), ...data}) + '\n'); } catch {} };

const FAILURE_LOG = path.join(process.env.HOME, '.claude', 'handoff', 'failures.json');

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

  // Only act on failures
  if (!hookData.tool_error && !hookData.error) return;

  const tool = hookData.tool_name || '';
  const error = hookData.tool_error || hookData.error || '';

  // Track consecutive failures
  let failures;
  try {
    failures = JSON.parse(fs.readFileSync(FAILURE_LOG, 'utf8'));
  } catch {
    failures = { consecutive: 0, last_tool: '', suggestions: [] };
  }

  if (failures.last_tool === tool) {
    failures.consecutive++;
  } else {
    failures.consecutive = 1;
    failures.last_tool = tool;
  }

  const suggestions = [];

  // MCP failure → suggest CLI fallback
  if (tool.startsWith('mcp__')) {
    suggestions.push(`MCP tool ${tool} failed. Try CLI fallback or ToolSearch for alternatives.`);
  }

  // Bash failure patterns
  if (tool === 'Bash') {
    if (error.includes('command not found')) {
      suggestions.push('Command not found — check PATH or install the tool.');
    }
    if (error.includes('permission denied')) {
      suggestions.push('Permission denied — check file permissions or use sudo if appropriate.');
    }
    if (error.includes('timeout')) {
      suggestions.push('Command timed out — try with a longer timeout or break into smaller steps.');
    }
  }

  // After 3 consecutive failures, escalate
  const outcome = failures.consecutive >= 3 ? 'escalate' : 'retry';
  logTelemetry({ event: 'self_heal', tool, attempt: failures.consecutive, outcome });
  if (failures.consecutive >= 3) {
    const failureContext = `Tool "${tool}" failed ${failures.consecutive} times consecutively. Last error: ${error.slice(0, 200)}`;
    suggestions.push(`ESCALATION: ${failureContext}. 3+ consecutive failures detected. Follow the Blocker Resolution table and Self-Healing Protocol in CLAUDE.md. Diagnose root cause, try a different approach, or log to DEFERRED.md.`);
    failures.consecutive = 0; // Reset after escalation
  }

  // Save failure state
  failures.suggestions = suggestions;
  const handoffDir = path.dirname(FAILURE_LOG);
  if (!fs.existsSync(handoffDir)) {
    fs.mkdirSync(handoffDir, { recursive: true });
  }
  fs.writeFileSync(FAILURE_LOG, JSON.stringify(failures, null, 2));

  if (suggestions.length > 0) {
    console.log(suggestions.join('\n'));
  }
}

try {
  main();
} catch (err) {
  try {
    const fs2 = require('fs');
    const path2 = require('path');
    fs2.appendFileSync(path2.join(process.env.HOME, '.claude', 'hook-errors.log'),
      `[${new Date().toISOString()}] [self-heal.js] ${err?.stack || err}\n`);
  } catch {}
}
