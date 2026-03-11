#!/usr/bin/env node

// PreToolUse hook: Convention verification + security checklist before writes
const fs = require('fs');
const path = require('path');

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

  const tool = hookData.tool_name || '';
  if (!['Write', 'Edit'].includes(tool)) return;

  const filePath = hookData.tool_input?.file_path || hookData.tool_input?.path || '';
  if (!filePath) return;

  const warnings = [];

  // Security checklist
  const content = hookData.tool_input?.content || hookData.tool_input?.new_string || '';

  // Check for hardcoded secrets
  if (/(?:password|secret|api.?key|token)\s*[:=]\s*['"][^'"]{8,}['"]/i.test(content)) {
    warnings.push('SECURITY: Possible hardcoded secret detected. Use environment variables.');
  }

  // Check for SQL injection risk (raw string interpolation in queries)
  if (/(?:query|sql|execute)\s*\(.*\$\{/i.test(content)) {
    warnings.push('SECURITY: Possible SQL injection — use parameterized queries.');
  }

  // Check for eval usage
  if (/\beval\s*\(/i.test(content)) {
    warnings.push('SECURITY: eval() detected — avoid dynamic code execution.');
  }

  // Convention: don't modify generated files
  const generatedPaths = ['_generated/', 'node_modules/', '.next/', 'dist/', 'build/'];
  if (generatedPaths.some(p => filePath.includes(p))) {
    warnings.push(`CONVENTION: ${filePath} appears to be a generated file — do not modify directly.`);
  }

  // Convention: don't modify lockfiles
  if (filePath.endsWith('pnpm-lock.yaml') || filePath.endsWith('package-lock.json') || filePath.endsWith('yarn.lock')) {
    warnings.push('CONVENTION: Lock files should not be edited manually.');
  }

  // Convention: don't modify env files
  if (path.basename(filePath).startsWith('.env')) {
    warnings.push('CONVENTION: .env files contain secrets — verify this change is intentional.');
  }

  if (warnings.length > 0) {
    console.log(warnings.join('\n'));
  }
}

try {
  main();
} catch (err) {
  try {
    const fs2 = require('fs');
    const path2 = require('path');
    fs2.appendFileSync(path2.join(process.env.HOME, '.claude', 'hook-errors.log'),
      `[${new Date().toISOString()}] [convention-check.js] ${err?.stack || err}\n`);
  } catch {}
}
