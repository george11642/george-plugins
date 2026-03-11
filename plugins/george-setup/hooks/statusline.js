#!/usr/bin/env node

// StatusLine hook: Premium ANSI statusline for Claude Code
// Layout: ⚡ fast·auto │ web-frontend │ t:42 │ ██████░░░░ 58% │ Implementing auth flow │ [ro][tdd]
const fs = require('fs');
const path = require('path');
const os = require('os');

const HOME = process.env.HOME || os.homedir();
const CLAUDE_DIR = process.env.CLAUDE_CONFIG_DIR || path.join(HOME, '.claude');
const BEHAVIOR_PATH = path.join(CLAUDE_DIR, 'behavior.json');
const ERROR_LOG = path.join(CLAUDE_DIR, 'hook-errors.log');

// ── ANSI helpers ──────────────────────────────────────────────────────
const A = {
  reset:   '\x1b[0m',
  dim:     '\x1b[2m',
  bold:    '\x1b[1m',
  green:   '\x1b[32m',
  yellow:  '\x1b[33m',
  cyan:    '\x1b[36m',
  red:     '\x1b[31m',
  white:   '\x1b[97m',
  orange:  '\x1b[38;5;208m',
  blink:   '\x1b[5;31m',
  dimW:    '\x1b[2;37m',
};

const sep = `${A.dim} │ ${A.reset}`;

function _logError(err) {
  try {
    fs.appendFileSync(ERROR_LOG,
      `[${new Date().toISOString()}] [statusline.js] ${err?.stack || err}\n`);
  } catch {}
}

// ── Stdin with 3s timeout ─────────────────────────────────────────────
const stdinTimeout = setTimeout(() => {
  try { render(null); } catch (err) { _logError(err); }
  process.exit(0);
}, 3000);

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  clearTimeout(stdinTimeout);
  try {
    let stdinData = null;
    try { stdinData = JSON.parse(input); } catch {}
    render(stdinData);
  } catch (err) {
    _logError(err);
  }
});

// ── Main render ───────────────────────────────────────────────────────
function render(stdinData) {
  let behavior;
  try {
    behavior = JSON.parse(fs.readFileSync(BEHAVIOR_PATH, 'utf8'));
  } catch {
    behavior = { autonomy: 'autonomous', toggles: {}, tool_call_count: 0 };
  }

  const parts = [];

  // 1. Mode badge
  parts.push(modeBadge(behavior));

  // 2. Active domain
  const domain = behavior.active_domain;
  parts.push(domain ? `${A.white}${domain}${A.reset}` : `${A.dim}—${A.reset}`);

  // 3. Tool count
  const tools = behavior.tool_call_count || 0;
  parts.push(`${A.dimW}t:${tools}${A.reset}`);

  // 4. Context bar
  const ctxResult = contextBar(stdinData);
  if (ctxResult.label) parts.push(ctxResult.label);

  // 5. Active task from todos
  const session = stdinData?.session_id || '';
  const task = getActiveTask(session);
  if (task) parts.push(`${A.bold}${A.white}${task}${A.reset}`);

  // 6. Active toggles
  const toggleBadges = getToggleBadges(behavior);
  if (toggleBadges) parts.push(toggleBadges);

  // 7. GSD update check
  const gsd = gsdUpdateBadge();
  if (gsd) parts.push(gsd);

  // Write context bridge file (side-effect)
  if (ctxResult.bridgeData && session) {
    try {
      const bridgePath = path.join(os.tmpdir(), `claude-ctx-${session}.json`);
      fs.writeFileSync(bridgePath, JSON.stringify(ctxResult.bridgeData));
    } catch {}
  }

  process.stdout.write(parts.join(sep));
}

// ── Components ────────────────────────────────────────────────────────

function modeBadge(b) {
  const aut = b.autonomy === 'autonomous' ? 'auto' : 'guided';
  const ro = b.toggles?.readonly;

  let icon, color;
  if (aut === 'guided') {
    icon = '⚡'; color = A.cyan;
  } else {
    icon = '⚡'; color = A.dim;
  }

  const prefix = ro ? `${A.red}🔒 ${A.reset}` : '';
  return `${prefix}${color}${icon} ${aut}${A.reset}`;
}

function contextBar(stdinData) {
  if (!stdinData) return { label: '', bridgeData: null };

  const remaining = stdinData.context_window?.remaining_percentage;
  if (remaining == null) return { label: '', bridgeData: null };

  const AUTO_COMPACT_BUFFER_PCT = 16.5;
  const usableRemaining = Math.max(0,
    ((remaining - AUTO_COMPACT_BUFFER_PCT) / (100 - AUTO_COMPACT_BUFFER_PCT)) * 100);
  const used = Math.max(0, Math.min(100, Math.round(100 - usableRemaining)));

  const filled = Math.floor(used / 10);
  const bar = '█'.repeat(filled) + '░'.repeat(10 - filled);

  let label;
  if (used < 50) {
    label = `${A.green}${bar} ${used}%${A.reset}`;
  } else if (used < 65) {
    label = `${A.yellow}${bar} ${used}%${A.reset}`;
  } else if (used < 80) {
    label = `${A.orange}${bar} ${used}%${A.reset}`;
  } else {
    label = `${A.blink}💀 ${bar} ${used}%${A.reset}`;
  }

  const bridgeData = {
    session_id: stdinData.session_id,
    remaining_percentage: remaining,
    used_pct: used,
    timestamp: Math.floor(Date.now() / 1000),
  };

  return { label, bridgeData };
}

function getActiveTask(session) {
  if (!session) return '';
  const todosDir = path.join(CLAUDE_DIR, 'todos');
  try {
    if (!fs.existsSync(todosDir)) return '';
    const files = fs.readdirSync(todosDir)
      .filter(f => f.startsWith(session) && f.includes('-agent-') && f.endsWith('.json'))
      .map(f => ({ name: f, mtime: fs.statSync(path.join(todosDir, f)).mtime }))
      .sort((a, b) => b.mtime - a.mtime);

    if (files.length === 0) return '';
    const todos = JSON.parse(fs.readFileSync(path.join(todosDir, files[0].name), 'utf8'));
    const active = todos.find(t => t.status === 'in_progress');
    if (!active) return '';
    const text = active.activeForm || active.content || '';
    return text.length > 40 ? text.slice(0, 37) + '…' : text;
  } catch {
    return '';
  }
}

function getToggleBadges(behavior) {
  const map = {
    readonly: 'ro',
    tdd_gate: 'tdd',
    plan_gate: 'plan',
    brainstorm_gate: 'brn',
    screenshot_verify: 'ss',
  };
  const on = Object.entries(behavior.toggles || {})
    .filter(([, v]) => v)
    .map(([k]) => `${A.dim}[${map[k] || k}]${A.reset}`)
    .join('');
  return on || '';
}

function gsdUpdateBadge() {
  try {
    const cacheFile = path.join(CLAUDE_DIR, 'cache', 'gsd-update-check.json');
    if (!fs.existsSync(cacheFile)) return '';
    const cache = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
    return cache.update_available ? `${A.yellow}⬆${A.reset}` : '';
  } catch {
    return '';
  }
}
