#!/usr/bin/env node

// UserPromptSubmit hook: Enforce brainstorm_gate, tdd_gate, plan_gate toggles
// Reads behavior.json and injects constraint messages when gates are active.
const fs = require('fs');
const path = require('path');

const BEHAVIOR_PATH = path.join(process.env.HOME, '.claude', 'behavior.json');

function main() {
  let rawInput = '';
  try {
    rawInput = fs.readFileSync(0, 'utf8');
  } catch {
    return;
  }

  // Parse the user prompt to check if it's a mode switch (skip enforcement for those)
  let input = '';
  try {
    const hookData = JSON.parse(rawInput);
    input = hookData.prompt || hookData.message || hookData.content || hookData.user_message || '';
  } catch {
    input = rawInput;
  }

  if (!input.trim() || /^\/mode\b/i.test(input.trim())) return;

  let behavior;
  try {
    behavior = JSON.parse(fs.readFileSync(BEHAVIOR_PATH, 'utf8'));
  } catch {
    return;
  }

  const toggles = behavior.toggles || {};
  const messages = [];

  if (toggles.brainstorm_gate) {
    messages.push(
      'BRAINSTORM GATE is ON: Before implementing any feature or creative work, ' +
      'brainstorm at least 3 alternative approaches and evaluate trade-offs. ' +
      'Present the options before writing any implementation code.'
    );
  }

  if (toggles.tdd_gate) {
    messages.push(
      'TDD GATE is ON: Write failing tests FIRST before writing any implementation code. ' +
      'Follow the red-green-refactor cycle: (1) write a failing test, (2) write minimal code to pass, (3) refactor.'
    );
  }

  if (toggles.plan_gate) {
    messages.push(
      'PLAN GATE is ON: Before implementing, create a step-by-step plan covering: ' +
      'files to change, approach, risks, and verification steps. ' +
      'Present the plan and get confirmation before writing code.'
    );
  }

  if (messages.length > 0) {
    console.log(messages.join('\n\n'));
  }
}

try {
  main();
} catch (err) {
  try {
    fs.appendFileSync(path.join(process.env.HOME, '.claude', 'hook-errors.log'),
      `[${new Date().toISOString()}] [gate-enforcer.js] ${err?.stack || err}\n`);
  } catch {}
}
