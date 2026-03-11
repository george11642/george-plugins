#!/usr/bin/env node

// PostToolUse hook: Budget circuit breaker — warns at soft limit, blocks at hard limit
const fs = require('fs');
const path = require('path');

const BUDGET_PATH = path.join(process.env.HOME, '.claude', 'budget.json');
const TELEMETRY_PATH = path.join(process.env.HOME, '.claude', 'telemetry.jsonl');

function getSessionId() {
  // Try to read session info from stdin, fall back to PPID for session scoping
  return process.env.CLAUDE_SESSION_ID || `pid-${process.ppid}`;
}

function getCounterPath(sessionId) {
  // Sanitize session ID for use in filename
  const safe = sessionId.replace(/[^a-zA-Z0-9_-]/g, '_');
  return `/tmp/claude-budget-${safe}.json`;
}

function logTelemetry(event, data) {
  try {
    const entry = {
      ts: new Date().toISOString(),
      event,
      ...data
    };
    fs.appendFileSync(TELEMETRY_PATH, JSON.stringify(entry) + '\n');
  } catch {}
}

function main() {
  // Load budget config
  let budget;
  try {
    budget = JSON.parse(fs.readFileSync(BUDGET_PATH, 'utf8'));
  } catch {
    return; // No config = no enforcement
  }

  if (!budget.enabled) return;

  const sessionId = getSessionId();
  const counterPath = getCounterPath(sessionId);

  // Load/increment counter
  let counter;
  try {
    counter = JSON.parse(fs.readFileSync(counterPath, 'utf8'));
  } catch {
    counter = { count: 0, session_id: sessionId, started: new Date().toISOString() };
  }

  counter.count += 1;
  counter.last_call = new Date().toISOString();
  fs.writeFileSync(counterPath, JSON.stringify(counter));

  const n = counter.count;
  const softLimit = budget.soft_limit || 150;
  const hardLimit = budget.hard_limit || 200;
  const warnInterval = budget.warn_interval || 10;

  // Hard limit check
  if (n >= hardLimit) {
    const msg = `\u{1f6d1} Budget limit reached: ${n}/${hardLimit} tool calls. Session should wrap up.`;
    console.log(msg);
    logTelemetry('budget_breaker', { count: n, hard_limit: hardLimit, session_id: sessionId });
    process.exit(2);
  }

  // Soft limit check — only warn every warn_interval calls after soft limit
  if (n >= softLimit) {
    const callsSinceSoft = n - softLimit;
    if (callsSinceSoft === 0 || callsSinceSoft % warnInterval === 0) {
      const pct = Math.round((n / hardLimit) * 100);
      const msg = `\u26a0 Budget warning: ${n}/${hardLimit} tool calls used (${pct}%)`;
      console.log(msg);
      logTelemetry('budget_warning', { count: n, soft_limit: softLimit, hard_limit: hardLimit, pct, session_id: sessionId });
    }
  }
}

try {
  main();
} catch (err) {
  try {
    fs.appendFileSync(path.join(process.env.HOME, '.claude', 'hook-errors.log'),
      `[${new Date().toISOString()}] [budget-breaker.js] ${err?.stack || err}\n`);
  } catch {}
}
