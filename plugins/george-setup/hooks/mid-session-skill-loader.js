#!/usr/bin/env node

// PostToolUse hook: Detect domain from tool usage and suggest skills mid-session
const fs = require('fs');
const STATE_PATH = '/home/george/.claude/mid-session-skills.json';
const BEHAVIOR_PATH = '/home/george/.claude/behavior.json';

const DOMAIN_SIGNALS = {
  'db-convex': {
    paths: ['packages/convex/convex/', 'convex/schema.ts'],
    bash: /\b(npx convex|convex dev|convex deploy|convex run)\b/
  },
  'web-frontend': {
    paths: ['apps/web/'],
    bash: /\b(next dev|next build)\b/
  },
  'auth-clerk': {
    paths: ['middleware.ts'],
    bash: null
  },
  'deploy-modal': {
    paths: ['workers/workers/', 'workers/deploy'],
    bash: /\b(modal deploy|modal serve|modal run)\b/
  },
  'deploy-vercel': {
    paths: ['vercel.json', '.vercel/'],
    bash: /\b(vercel deploy|vercel env|vercel logs)\b/
  },
  'testing-quality': {
    paths: ['__tests__/', '.test.', '.spec.', 'playwright/'],
    bash: /\b(vitest|playwright test|pnpm test|pytest)\b/
  },
  'git-workflow': {
    paths: [],
    bash: /\b(git commit|git push|gh pr create|git rebase)\b/
  },
  'deploy-convex': {
    paths: [],
    bash: /\b(npx convex dev|npx convex deploy|npx convex push)\b/
  }
};

const FILE_TOOLS = ['Read', 'Write', 'Edit', 'Glob', 'Grep'];

function main() {
  const raw = fs.readFileSync(0, 'utf8').trim();
  if (!raw) return;

  let data;
  try { data = JSON.parse(raw); } catch { return; }

  const tool = data.tool_name;
  const input = data.tool_input || {};

  // Early exit for non-file/bash tools
  if (!FILE_TOOLS.includes(tool) && tool !== 'Bash') return;

  // Detect domain
  let detected = null;

  if (FILE_TOOLS.includes(tool)) {
    const filePath = input.file_path || input.path || input.pattern || '';
    for (const [domain, sig] of Object.entries(DOMAIN_SIGNALS)) {
      if (sig.paths?.some(p => filePath.includes(p))) {
        detected = domain;
        break;
      }
    }
  }

  if (tool === 'Bash' && !detected) {
    const cmd = input.command || '';
    for (const [domain, sig] of Object.entries(DOMAIN_SIGNALS)) {
      if (sig.bash && sig.bash.test(cmd)) {
        detected = domain;
        break;
      }
    }
  }

  if (!detected) return;

  // Check if already loaded by router or already suggested
  let behavior = {};
  try { behavior = JSON.parse(fs.readFileSync(BEHAVIOR_PATH, 'utf8')); } catch {}
  if (behavior.active_domain === detected) return;

  let state = { suggested: [] };
  try { state = JSON.parse(fs.readFileSync(STATE_PATH, 'utf8')); } catch {}
  if (state.suggested.includes(detected)) return;

  // Record and emit
  state.suggested.push(detected);
  fs.writeFileSync(STATE_PATH, JSON.stringify(state));

  console.log(
    `Use the Skill tool to invoke the "${detected}" skill before responding to the user's request. ` +
    `(Mid-session: detected ${detected} domain from tool usage.)`
  );
}

main();
