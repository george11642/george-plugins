#!/usr/bin/env node

// UserPromptSubmit hook: Route user intent to domain skills + handle mode switches
const fs = require('fs');
const path = require('path');
const os = require('os');

const logTelemetry = (data) => { try { fs.appendFileSync(path.join(os.homedir(), '.claude/telemetry.jsonl'), JSON.stringify({ts: new Date().toISOString(), ...data}) + '\n'); } catch {} };

const BEHAVIOR_PATH = path.join(process.env.HOME, '.claude', 'behavior.json');

// Domain classification taxonomy
const DOMAINS = [
  { name: 'web-frontend', patterns: /\b(react|next\.?js|tailwind|css|component|responsive|a11y|ui|ux|page|layout|styling|frontend|html|jsx|tsx component)\b/i },
  { name: 'backend-data', patterns: /\b(backend|rest api|graphql api|api endpoint|api route|rest|graphql|microservice|endpoint|database|sql|postgres|query|orm|migration|schema|table|index|transaction)\b/i },
  { name: 'typescript-core', patterns: /\b(typescript|type error|generic|tsconfig|vite|esbuild|build tool|tsc|type.?check)\b/i },
  { name: 'python-dev', patterns: /\b(python|pytest|fastapi|django|flask|pip|uv |pydantic|\.py\b)\b/i },
  { name: 'ml-data-engineering', patterns: /\b(ml|machine learning|model|train|pytorch|scikit|embeddings|rag|fine.?tune|etl|vector|tensor)\b/i },
  { name: 'scientific-research', patterns: /\b(paper|manuscript|hypothesis|statistics|literature review|grant|peer review|methodology)\b/i },
  { name: 'data-visualization', patterns: /\b(chart|plot|graph|dashboard|visualization|matplotlib|plotly|d3|infographic)\b/i },
  { name: 'cloud-infra', patterns: /\b(docker|kubernetes|terraform|cicd|aws|gcp|shell|bash|systemd|nginx|ci.?cd)\b/i },
  { name: 'mobile-native', patterns: /\b(expo|react native|ios|android|swiftui|kotlin|app store|mobile)\b/i },
  { name: 'security-deep', patterns: /\b(security|oauth|jwt|encryption|owasp|soc2|gdpr|vulnerability|penetration)\b/i },
  { name: 'auth-clerk', patterns: /\b(clerk|sign.?in|sign.?up|login|log.?in|authentication|auth middleware|ClerkProvider|auth page|auth flow|clerk.?captcha)\b/i },
  { name: 'seo-growth', patterns: /\b(seo|search engine|schema markup|analytics|ga4|keyword|sitemap|crawl)\b/i },
  { name: 'marketing', patterns: /\b(marketing|blog post|social media post|email campaign|newsletter|content calendar|ad copy|product hunt|go.?to.?market|gtm|launch plan|content strategy|copywriting|landing page copy|pseo|twitter thread|linkedin post|lead magnet|drip campaign|marketing funnel|paid ads|growth marketing|content marketing)\b/i },
  { name: 'presentations-docs', patterns: /\b(presentation|slides|poster|pptx|beamer|deck|latex)\b/i },
  { name: 'research-tools', patterns: /\b(notebooklm|notebook|audio overview|study guide|synthesize sources|youtube research|obsidian|vault|obsidian note|research pipeline)\b/i },
  { name: 'monitoring-sentry', patterns: /\b(sentry|sentry error|production error|error spike|crash report|triage errors)\b/i },
  { name: 'payments-stripe', patterns: /\b(stripe|stripe checkout|stripe webhook|subscription billing|payment intent)\b/i },
  { name: 'analytics-posthog', patterns: /\b(posthog|feature flag|A\/B test posthog|analytics event|funnel|HogQL)\b/i },
  { name: 'mcp-gemini', patterns: /\b(gemini|analyze image|generate image|gemini search|text to speech|CAPTCHA)\b/i },
  { name: 'db-convex', patterns: /\b(convex schema|defineTable|convex quer|convex mutation|convex action|httpAction|convex workflow|convex cron)\b/i },
  { name: 'db-supabase', patterns: /\b(supabase|supabase migration|supabase sql|supabase edge function|supabase rls)\b/i },
  { name: 'deploy-convex', patterns: /\b(npx convex|convex dev|convex deploy|convex push|convex run)\b/i },
  { name: 'deploy-modal', patterns: /\b(modal deploy|modal worker|modal app|modal logs|modal secret)\b/i },
  { name: 'deploy-vercel', patterns: /\b(vercel deploy|vercel prod|vercel preview|vercel env|vercel logs)\b/i },
  { name: 'git-workflow', patterns: /\b(git commit|git push|git stash|pull request|create pr|gh pr|merge conflict|cherry.pick|git rebase|git branch)\b/i },
  { name: 'testing-quality', patterns: /\b(unit test|vitest|playwright|e2e test|pytest|type.check|pnpm test|test coverage|run tests)\b/i },
  { name: 'browser-agent', patterns: /\b(screenshot|browser automation|fill form|click button|visual verif)\b/i },
  { name: 'skill-creator', patterns: /\b(create skill|new skill|skill description|optimize skill|skill eval|skill trigger)\b/i },
];

// Mode switch patterns
const MODE_PRESETS = [
  { pattern: /\/mode[- ]?(guided|superpowers)/i, name: 'guided', action: { autonomy: 'guided' } },
  { pattern: /\/mode[- ]?(readonly|research)/i, name: 'readonly', action: { autonomy: 'guided', toggles_set: { readonly: true } } },
  { pattern: /\/mode[- ]?(autonomous|fast|quick|ship)/i, name: 'autonomous', action: { autonomy: 'autonomous' } },
];
const VALID_PRESETS = MODE_PRESETS.map(p => p.name);

function main() {
  let rawInput = '';
  try {
    rawInput = fs.readFileSync(0, 'utf8');
  } catch {
    return;
  }

  let input = '';
  try {
    const hookData = JSON.parse(rawInput);
    input = hookData.prompt || hookData.message || hookData.content || hookData.user_message || '';
  } catch {
    input = rawInput;
  }

  if (!input.trim()) return;

  // Skip system/machine-generated messages
  if (/^<(task-notification|system-reminder|command-|local-command)/.test(input.trim())) return;

  let behavior;
  try {
    behavior = JSON.parse(fs.readFileSync(BEHAVIOR_PATH, 'utf8'));
  } catch {
    return;
  }

  // Bare /mode — show current state and available presets
  if (/\/mode\s*$/i.test(input.trim())) {
    const toggleList = Object.entries(behavior.toggles).map(([k, v]) => `  ${k}: ${v}`).join('\n');
    console.log(`Current mode: autonomy=${behavior.autonomy}\nToggles:\n${toggleList}\n\nAvailable presets: ${VALID_PRESETS.join(', ')}`);
    return;
  }

  // Check for mode switches
  for (const { pattern, action } of MODE_PRESETS) {
    if (pattern.test(input)) {
      // Reset ALL toggles to false before applying preset-specific ones
      for (const key of Object.keys(behavior.toggles)) behavior.toggles[key] = false;
      if (action.autonomy) behavior.autonomy = action.autonomy;
      if (action.toggles_set) Object.assign(behavior.toggles, action.toggles_set);
      fs.writeFileSync(BEHAVIOR_PATH, JSON.stringify(behavior, null, 2));
      console.log(`Mode switched: autonomy=${behavior.autonomy}`);
      return;
    }
  }

  // Invalid /mode argument
  if (/\/mode\s+\S+/i.test(input)) {
    console.log(`Unknown mode preset. Valid presets: ${VALID_PRESETS.join(', ')}`);
    return;
  }

  // Classify domain(s)
  const matched = DOMAINS.filter(d => d.patterns.test(input)).map(d => d.name);
  const preview = input.slice(0, 30).replace(/\n/g, ' ');
  const confidence = matched.length === 0 ? 'none' : matched.length === 1 ? 'single' : 'ambiguous';
  logTelemetry({ event: 'route', input_preview: preview, matched: matched[0] || null, also_matched: matched.slice(1), confidence });

  if (matched.length === 1) {
    if (behavior.active_domain !== matched[0]) {
      behavior.active_domain = matched[0];
      fs.writeFileSync(BEHAVIOR_PATH, JSON.stringify(behavior, null, 2));
      console.log(`Use the Skill tool to invoke the "${matched[0]}" skill before responding to the user's request.`);
    } else {
      logTelemetry({ event: 'route_reuse', reused: matched[0] });
    }
  } else if (matched.length >= 2 && matched.length <= 3) {
    if (behavior.active_domain !== matched[0]) {
      behavior.active_domain = matched[0];
      fs.writeFileSync(BEHAVIOR_PATH, JSON.stringify(behavior, null, 2));
      console.log(`Use the Skill tool to invoke the "${matched[0]}" skill before responding to the user's request.`);
    } else {
      logTelemetry({ event: 'route_reuse_multi', reused: matched[0], skipped: matched.slice(1) });
    }
    logTelemetry({ event: 'route_multi', loaded: matched[0], skipped: matched.slice(1) });
  } else {
    // 0 or 4+ matches — let Claude's native matching handle it
    logTelemetry({ event: 'route_passthrough', matched_count: matched.length, matched });
  }
}

try {
  main();
} catch (err) {
  try {
    fs.appendFileSync(path.join(process.env.HOME, '.claude', 'hook-errors.log'),
      `[${new Date().toISOString()}] [router.js] ${err?.stack || err}\n`);
  } catch {}
}
