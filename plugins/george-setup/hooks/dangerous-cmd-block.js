#!/usr/bin/env node

// PreToolUse hook: Block dangerous bash commands before execution
const fs = require('fs');
const path = require('path');

const WHITELIST_PATH = path.join(process.env.HOME, '.claude', 'dangerous-cmd-whitelist.json');
const TELEMETRY_PATH = path.join(process.env.HOME, '.claude', 'telemetry.jsonl');

const DANGEROUS_PATTERNS = [
  {
    pattern: /\brm\s+-[^\s]*r[^\s]*f[^\s]*\s+\/(\s|$|\*)|\brm\s+-[^\s]*f[^\s]*r[^\s]*\s+\/(\s|$|\*)/,
    reason: 'Recursive forced deletion of root filesystem'
  },
  {
    pattern: /:\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:/,
    reason: 'Fork bomb detected — will crash the system by exhausting process table'
  },
  {
    pattern: /\bdd\b.*\bif\s*=\s*\/dev\/(zero|random|urandom)\b.*\bof\s*=\s*\/dev\/[a-z]/,
    reason: 'Disk wipe via dd — overwrites raw block device with zeros'
  },
  {
    pattern: /\bmkfs\b/,
    reason: 'Filesystem format command — will destroy all data on the target device'
  },
  {
    pattern: />\s*\/dev\/sd[a-z]/,
    reason: 'Redirect to raw block device — will destroy disk contents'
  },
  {
    pattern: /\becho\b.*\|\s*base64\s+-d\s*\|\s*(bash|sh)\b/,
    reason: 'Base64-encoded command piped to shell — obfuscated execution is dangerous'
  },
  {
    pattern: /\bchmod\s+-[^\s]*R[^\s]*\s+777\s+\/(\s|$)|\bchmod\s+.*777\s+-[^\s]*R[^\s]*\s+\/(\s|$)/,
    reason: 'Recursive chmod 777 on root — destroys all file permissions system-wide'
  },
  {
    pattern: /\b(wget|curl)\b.*\|\s*(bash|sh)\b/,
    reason: 'Piping remote content directly to shell — arbitrary remote code execution'
  },
  {
    pattern: /\b(shutdown|reboot|halt|poweroff)\b/,
    reason: 'System shutdown/reboot command — will terminate the running system'
  },
  {
    pattern: /\biptables\s+-F\b/,
    reason: 'Flushing all firewall rules — exposes system to network attacks'
  }
];

function loadWhitelist() {
  try {
    const data = fs.readFileSync(WHITELIST_PATH, 'utf8');
    const patterns = JSON.parse(data);
    return patterns.map(p => new RegExp(p));
  } catch {
    return [];
  }
}

function logBlock(command, reason) {
  try {
    const entry = JSON.stringify({
      event: 'dangerous_cmd_blocked',
      timestamp: new Date().toISOString(),
      command,
      reason
    });
    fs.appendFileSync(TELEMETRY_PATH, entry + '\n');
  } catch {}
}

function main() {
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
  if (tool !== 'Bash') return;

  const cmd = hookData.tool_input?.command || '';
  if (!cmd) return;

  const whitelist = loadWhitelist();

  for (const { pattern, reason } of DANGEROUS_PATTERNS) {
    if (pattern.test(cmd)) {
      // Check whitelist — if any whitelist pattern matches the command, allow it
      const whitelisted = whitelist.some(wp => wp.test(cmd));
      if (whitelisted) continue;

      logBlock(cmd, reason);
      console.log(JSON.stringify({
        decision: 'block',
        reason: `DANGEROUS COMMAND BLOCKED: ${reason}\nCommand: ${cmd}`
      }));
      return;
    }
  }
}

try {
  main();
} catch (err) {
  try {
    const fs2 = require('fs');
    const path2 = require('path');
    fs2.appendFileSync(path2.join(process.env.HOME, '.claude', 'hook-errors.log'),
      `[${new Date().toISOString()}] [dangerous-cmd-block.js] ${err?.stack || err}\n`);
  } catch {}
}
