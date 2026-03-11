#!/usr/bin/env node

// SessionStart hook: Initialize session state
const fs = require('fs');
const path = require('path');
const os = require('os');

const logTelemetry = (data) => { try { fs.appendFileSync(path.join(os.homedir(), '.claude/telemetry.jsonl'), JSON.stringify({ts: new Date().toISOString(), ...data}) + '\n'); } catch {} };

const BEHAVIOR_PATH = path.join(process.env.HOME, '.claude', 'behavior.json');
const HANDOFF_PATH = path.join(process.env.HOME, '.claude', 'handoff', 'HANDOFF.md');
const PATTERNS_PATH = path.join(process.env.HOME, '.claude', 'session-patterns.json');

async function main() {
  // Read or create behavior.json
  let behavior;
  try {
    behavior = JSON.parse(fs.readFileSync(BEHAVIOR_PATH, 'utf8'));
  } catch {
    behavior = {
      autonomy: 'autonomous',
      toggles: { readonly: false, brainstorm_gate: false, tdd_gate: false, plan_gate: false, screenshot_verify: false },
      active_domain: null,
      tool_call_count: 0,
      session_start: null,
      last_heartbeat: null
    };
  }

  // Reset session state
  behavior.tool_call_count = 0;
  behavior.session_start = new Date().toISOString();
  behavior.active_domain = null;
  fs.writeFileSync(BEHAVIOR_PATH, JSON.stringify(behavior, null, 2));

  // Reset mid-session skill suggestions
  try { fs.unlinkSync('/home/george/.claude/mid-session-skills.json'); } catch {}

  // Build context output
  const parts = [];
  parts.push(`Mode: autonomy=${behavior.autonomy}`);

  const activeToggles = Object.entries(behavior.toggles)
    .filter(([, v]) => v)
    .map(([k]) => k);
  if (activeToggles.length > 0) {
    parts.push(`Active toggles: ${activeToggles.join(', ')}`);
  }

  // Check for handoff from previous session (post-compaction recovery)
  const recoveredHandoff = fs.existsSync(HANDOFF_PATH);
  logTelemetry({ event: 'session_start', recovered_handoff: recoveredHandoff });
  if (recoveredHandoff) {
    const handoff = fs.readFileSync(HANDOFF_PATH, 'utf8');
    parts.push('\n--- SESSION HANDOFF (from previous compaction) ---');
    parts.push(handoff);
    parts.push('--- END HANDOFF ---');
    // Archive so future sessions don't see stale handoff data
    const consumed = HANDOFF_PATH + '.consumed';
    fs.renameSync(HANDOFF_PATH, consumed);
  }

  // Detect project type from cwd
  const cwd = process.cwd();
  if (fs.existsSync(path.join(cwd, 'package.json'))) {
    try {
      const pkg = JSON.parse(fs.readFileSync(path.join(cwd, 'package.json'), 'utf8'));
      if (pkg.dependencies?.next || pkg.devDependencies?.next) parts.push('Project: Next.js');
      else if (pkg.dependencies?.react) parts.push('Project: React');
      else if (pkg.dependencies?.express) parts.push('Project: Express');
    } catch {}
  }
  if (fs.existsSync(path.join(cwd, 'convex'))) parts.push('Project: Convex detected');
  if (fs.existsSync(path.join(cwd, 'modal.toml')) || fs.existsSync(path.join(cwd, 'workers'))) parts.push('Project: Modal workers detected');

  // Cross-session pattern insights
  try {
    const patterns = JSON.parse(fs.readFileSync(PATTERNS_PATH, 'utf8'));
    if (patterns.sessions >= 3) {
      const insights = [];
      // Check for dominant domain
      const totalDomainSessions = Object.values(patterns.domain_frequency).reduce((a, b) => a + b, 0);
      if (totalDomainSessions > 0) {
        const topDomain = Object.entries(patterns.domain_frequency).sort((a, b) => b[1] - a[1])[0];
        const pct = Math.round((topDomain[1] / totalDomainSessions) * 100);
        if (pct > 50) {
          insights.push(`Most frequent domain: ${topDomain[0]} (${pct}% of ${patterns.sessions} sessions)`);
        }
      }
      // Check for long sessions
      if (patterns.avg_tool_calls > 50) {
        insights.push(`Sessions tend to be long (~${patterns.avg_tool_calls} tool calls avg)`);
      }
      if (insights.length > 0) {
        parts.push(`Patterns: ${insights.join(' | ')}`);
      }
    }
  } catch {
    // Never block boot on pattern read failure
  }

  if (parts.length > 0) {
    console.log(parts.join('\n'));
  }
}

main().catch((err) => {
  try {
    const fs2 = require('fs');
    const path2 = require('path');
    fs2.appendFileSync(path2.join(process.env.HOME, '.claude', 'hook-errors.log'),
      `[${new Date().toISOString()}] [boot.js] ${err?.stack || err}\n`);
  } catch {}
});
