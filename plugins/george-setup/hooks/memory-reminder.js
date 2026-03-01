#!/usr/bin/env node
// Stop hook: reminds Claude to write memory after substantive sessions.
// Fires once per session. Exit 2 + stderr = Claude receives the message.

const fs = require("fs");
const path = require("path");
const readline = require("readline");

const TOOL_USE_THRESHOLD = 8;
const CACHE_DIR = path.join(process.env.HOME, ".claude", "cache");

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return JSON.parse(Buffer.concat(chunks).toString());
}

function countToolUses(transcriptPath) {
  try {
    const content = fs.readFileSync(transcriptPath, "utf8");
    const lines = content.split("\n").filter(Boolean);
    let count = 0;
    for (const line of lines) {
      try {
        const msg = JSON.parse(line);
        if (msg.type === "assistant" && Array.isArray(msg.message?.content)) {
          for (const block of msg.message.content) {
            if (block.type === "tool_use") count++;
          }
        }
      } catch {}
    }
    return count;
  } catch {
    return 0;
  }
}

async function main() {
  const input = await readStdin();

  // Prevent infinite loop: if this hook already triggered a response, exit clean
  if (input.stop_hook_active) process.exit(0);

  const sessionId = input.session_id;
  if (!sessionId) process.exit(0);

  // One reminder per session
  fs.mkdirSync(CACHE_DIR, { recursive: true });
  const flagFile = path.join(CACHE_DIR, `memory-reminded-${sessionId}`);
  if (fs.existsSync(flagFile)) process.exit(0);

  // Skip trivial sessions
  const transcriptPath = input.transcript_path;
  if (!transcriptPath || countToolUses(transcriptPath) < TOOL_USE_THRESHOLD) {
    process.exit(0);
  }

  // Write flag so we don't fire again this session
  fs.writeFileSync(flagFile, Date.now().toString());

  // Memory reminder is handled by global CLAUDE.md instructions.
  // Exit 0 to avoid "Stop hook error" noise in the UI.
  process.exit(0);
}

main().catch(() => process.exit(0));
