# Ralph Marketer V2

Autonomous AI content marketing plugin for Claude Code. Ralph auto-detects your project's tech stack, generates targeted marketing content, and publishes it -- all while you sleep.

## What It Does

Ralph analyzes your codebase to understand your product, then autonomously creates and publishes marketing content tailored to your audience. It handles the full pipeline: research, writing, scheduling, and publishing across multiple channels.

## Installation

Install globally via the Claude Code plugin system:

```bash
claude plugin install ralph-marketer-v2
```

## Quick Start

1. **Initialize** Ralph in your project:
   ```
   /ralph-init
   ```
   Ralph scans your repo, identifies your stack, and generates a product research document (PRD) to guide content creation.

2. **Run** the content pipeline:
   ```
   /ralph-run
   ```
   Ralph begins creating and publishing content based on your PRD.

## Available Commands

| Command | Description |
|---------|-------------|
| `/ralph-init` | Scan your project and generate a PRD for content targeting |
| `/ralph-run` | Start the autonomous content creation and publishing pipeline |
| `/ralph-status` | Check the current state of content in the pipeline |
| `/ralph-cancel` | Cancel any in-progress content jobs |
| `/ralph-publish` | Manually trigger publishing for ready content |

## Project Layout

```
ralph-marketer-v2/
├── .claude-plugin/     # Plugin manifest
├── commands/           # Slash command definitions
├── skills/copywriter/  # Copywriting skill for content generation
├── scripts/
│   ├── src/            # Core logic (db, content, publish modules)
│   └── ralph/          # Per-project generated PRD and progress state
└── templates/          # Content and prompt templates
```
