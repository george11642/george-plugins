#!/usr/bin/env node

// Stop hook: Quality gate — semantic test verification for code domains
// Non-blocking: outputs advisory messages only, never prevents stop.
const fs = require('fs');
const path = require('path');
const os = require('os');

const logTelemetry = (data) => { try { fs.appendFileSync(path.join(os.homedir(), '.claude/telemetry.jsonl'), JSON.stringify({ts: new Date().toISOString(), ...data}) + '\n'); } catch {} };

const BEHAVIOR_PATH = path.join(process.env.HOME, '.claude', 'behavior.json');
const PATTERNS_PATH = path.join(process.env.HOME, '.claude', 'session-patterns.json');
const TRANSCRIPTS_DIR = path.join(process.env.HOME, '.claude', 'transcripts');

// Domains where code is likely being modified and tests matter
const CODE_DOMAINS = new Set([
  'web-frontend',
  'backend-data',
  'typescript-core',
  'python-dev',
  'db-convex',
  'deploy-convex',
  'deploy-modal',
]);

// Patterns that indicate test/type-check commands were run
const TEST_PATTERNS = [
  /\bpnpm\s+test\b/,
  /\bnpm\s+test\b/,
  /\byarn\s+test\b/,
  /\bvitest\b/,
  /\bjest\b/,
  /\bpytest\b/,
  /\bpnpm\s+type-check\b/,
  /\btsc\b.*--noEmit/,
  /\bnpx\s+tsc\b/,
  /\bplaywright\s+test\b/,
  /\bpnpm\s+lint\b/,
  /\bnpx\s+convex\s+dev\s+--once\b/,
];

// Timeout guard: exit silently if stdin doesn't close within 3s
const stdinTimeout = setTimeout(() => {
  runGate(null);
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
  runGate(stdinData);
});

function runGate(stdinData) {
  try {
    _runGate(stdinData);
  } catch (err) {
    try {
      fs.appendFileSync(path.join(process.env.HOME, '.claude', 'hook-errors.log'),
        `[${new Date().toISOString()}] [quality-gate.js] ${err?.stack || err}\n`);
    } catch {}
  }
}

function _runGate(stdinData) {
  let behavior;
  try {
    behavior = JSON.parse(fs.readFileSync(BEHAVIOR_PATH, 'utf8'));
  } catch {
    return;
  }

  const { tool_call_count = 0, active_domain } = behavior;
  const isCodeDomain = active_domain && CODE_DOMAINS.has(active_domain);

  // Semantic test verification for code domains with meaningful work
  let testStatus = 'skipped';
  if (isCodeDomain && tool_call_count > 10) {
    const sessionId = stdinData?.session_id;
    const evidence = checkForTestRuns(sessionId);

    if (evidence.testsRan) {
      testStatus = 'verified';
      console.log(`\u2713 Tests verified: ${evidence.commands.join(', ')}`);
    } else if (evidence.uncertain) {
      testStatus = 'uncertain';
      console.log(
        `\u26a0 ${tool_call_count} tool calls in "${active_domain}" \u2014 could not verify test runs. Consider: pnpm test && pnpm type-check`
      );
    } else {
      testStatus = 'missing';
      console.log(
        `\u26a0 No test run detected this session (${tool_call_count} tool calls in "${active_domain}"). Consider: pnpm test && pnpm type-check`
      );
    }
  }

  // Memory reminder after substantial work (any domain)
  if (tool_call_count > 10) {
    console.log('Memory: If you discovered a gotcha or pattern, update MEMORY.md.');
  }

  // Telemetry
  logTelemetry({
    event: 'quality_gate',
    domain: active_domain || 'none',
    tool_calls: tool_call_count,
    test_status: testStatus,
  });

  // Update cross-session patterns
  updatePatterns(behavior, active_domain, tool_call_count);
}

/**
 * Scan session transcript for Bash tool calls containing test commands.
 * Reads last ~100KB to avoid slow I/O on large transcripts.
 * Returns { testsRan: bool, uncertain: bool, commands: string[] }
 */
function checkForTestRuns(sessionId) {
  const result = { testsRan: false, uncertain: false, commands: [] };

  if (!sessionId) {
    result.uncertain = true;
    return result;
  }

  // Find transcript file for this session
  const transcriptFile = path.join(TRANSCRIPTS_DIR, `${sessionId}.jsonl`);
  if (!fs.existsSync(transcriptFile)) {
    result.uncertain = true;
    return result;
  }

  try {
    // Read last ~100KB of transcript to avoid reading huge files
    const stat = fs.statSync(transcriptFile);
    const readSize = Math.min(stat.size, 100 * 1024);
    const fd = fs.openSync(transcriptFile, 'r');
    const buffer = Buffer.alloc(readSize);
    fs.readSync(fd, buffer, 0, readSize, Math.max(0, stat.size - readSize));
    fs.closeSync(fd);

    const tail = buffer.toString('utf8');
    const lines = tail.split('\n').filter(Boolean);

    const foundCommands = new Set();

    for (const line of lines) {
      let entry;
      try {
        entry = JSON.parse(line);
      } catch {
        // Partial line from mid-file read, skip
        continue;
      }

      // Look for assistant tool_use entries with Bash tool
      const content = entry.message?.content || entry.content;
      if (!Array.isArray(content)) continue;

      for (const block of content) {
        if (block.type !== 'tool_use') continue;
        if (block.name !== 'Bash') continue;

        const cmd = block.input?.command || '';
        for (const pattern of TEST_PATTERNS) {
          if (pattern.test(cmd)) {
            const match = cmd.match(pattern);
            if (match) foundCommands.add(match[0].trim());
            break;
          }
        }
      }
    }

    if (foundCommands.size > 0) {
      result.testsRan = true;
      result.commands = [...foundCommands];
    }
  } catch {
    result.uncertain = true;
  }

  return result;
}

function updatePatterns(behavior, active_domain, tool_call_count) {
  try {
    let patterns;
    try {
      patterns = JSON.parse(fs.readFileSync(PATTERNS_PATH, 'utf8'));
    } catch {
      patterns = { sessions: 0, domain_frequency: {}, avg_tool_calls: 0, mode_switches: [], common_patterns: [] };
    }

    patterns.sessions += 1;

    if (active_domain) {
      patterns.domain_frequency[active_domain] = (patterns.domain_frequency[active_domain] || 0) + 1;
    }

    const prevTotal = patterns.avg_tool_calls * (patterns.sessions - 1);
    patterns.avg_tool_calls = Math.round((prevTotal + tool_call_count) / patterns.sessions);

    if (behavior.autonomy) {
      patterns.mode_switches.push({
        autonomy: behavior.autonomy,
        domain: active_domain || null,
        ts: new Date().toISOString()
      });
      if (patterns.mode_switches.length > 20) {
        patterns.mode_switches = patterns.mode_switches.slice(-20);
      }
    }

    fs.writeFileSync(PATTERNS_PATH, JSON.stringify(patterns, null, 2));
  } catch {
    // Never block stop on pattern tracking failure
  }
}
