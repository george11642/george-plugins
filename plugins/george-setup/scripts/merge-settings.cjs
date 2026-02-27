#!/usr/bin/env node
/**
 * merge-settings.cjs
 * Safely merges george-setup configuration into ~/.claude/settings.json.
 * - Never overwrites existing values (additive only)
 * - Backs up settings before modifying
 * - Idempotent — safe to run multiple times
 *
 * Usage: node merge-settings.cjs [--dry-run]
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const SETTINGS_PATH = path.join(os.homedir(), '.claude', 'settings.json');
const BACKUP_PATH = SETTINGS_PATH + '.backup';
const DRY_RUN = process.argv.includes('--dry-run');

// Configuration to merge
const MERGE_CONFIG = {
  env: {
    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: '1',
  },
  permissions: {
    // Allow dangerous mode without extra prompts (power-user setting)
    skipDangerousModePermissionPrompt: true,
  },
};

// MCP server entries to add
const MCP_SERVERS = {
  gemini: {
    command: 'node',
    args: [path.join(os.homedir(), '.claude', 'mcp-servers', 'gemini-mcp', 'dist', 'index.js')],
    env: {
      GEMINI_API_KEY: '${GEMINI_API_KEY}',
    },
  },
  latex: {
    command: path.join(os.homedir(), '.claude', 'scripts', 'latex-mcp-wrapper.sh'),
    args: [],
  },
};

function main() {
  let settings = {};

  // Read existing settings
  if (fs.existsSync(SETTINGS_PATH)) {
    try {
      settings = JSON.parse(fs.readFileSync(SETTINGS_PATH, 'utf8'));
    } catch (e) {
      console.error(`Failed to parse ${SETTINGS_PATH}:`, e.message);
      process.exit(1);
    }
  }

  // Backup
  if (!DRY_RUN && fs.existsSync(SETTINGS_PATH)) {
    fs.copyFileSync(SETTINGS_PATH, BACKUP_PATH);
    console.log(`Backed up to ${BACKUP_PATH}`);
  }

  // Merge env
  settings.env = { ...MERGE_CONFIG.env, ...(settings.env || {}) };

  // Merge permissions
  settings.permissions = { ...MERGE_CONFIG.permissions, ...(settings.permissions || {}) };

  // Add MCP servers (don't overwrite existing)
  if (!settings.mcpServers) settings.mcpServers = {};
  for (const [name, config] of Object.entries(MCP_SERVERS)) {
    if (!settings.mcpServers[name]) {
      settings.mcpServers[name] = config;
      console.log(`Added MCP server: ${name}`);
    } else {
      console.log(`MCP server already configured: ${name} (skipped)`);
    }
  }

  // Add statusLine (settings.json-only feature, not supported in plugin hooks.json)
  if (!settings.statusLine) {
    settings.statusLine = {
      type: 'command',
      command: `node "${path.join(os.homedir(), '.claude', 'plugins', 'marketplaces', 'george-plugins', 'plugins', 'george-setup', 'hooks', 'statusline.js')}"`,
    };
    console.log('Added statusLine configuration');
  } else {
    console.log('statusLine already configured (skipped)');
  }

  if (DRY_RUN) {
    console.log('\n--- Dry run result ---');
    console.log(JSON.stringify(settings, null, 2));
  } else {
    fs.writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2) + '\n');
    console.log(`\nSettings written to ${SETTINGS_PATH}`);
  }
}

main();
