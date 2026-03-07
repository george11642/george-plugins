# Web Artifacts: Claude.ai Artifact Building

## Overview
Build multi-component React artifacts for claude.ai using the web-artifacts-builder workflow. Use for complex artifacts requiring state management, routing, or shadcn/ui components.

## Stack
React 18 + TypeScript + Vite + Parcel (bundling) + Tailwind CSS + shadcn/ui

## Workflow

### 1. Initialize Project
```bash
bash scripts/init-artifact.sh <project-name>
cd <project-name>
```
Creates: React + TypeScript + Tailwind + 40+ shadcn/ui components pre-installed.

### 2. Develop
Edit generated files. Path aliases (`@/`) configured. All Radix UI dependencies included.

### 3. Bundle to Single HTML
```bash
bash scripts/bundle-artifact.sh
```
Creates `bundle.html` — self-contained artifact with all JS, CSS, dependencies inlined.

### 4. Share
Display bundled HTML as artifact in conversation.

## Anti-Slop Guidelines
- Avoid excessive centered layouts
- No default purple gradients
- No uniform rounded corners on everything
- Don't default to Inter font — choose typography intentionally
- Add visual hierarchy through size, weight, color contrast
- Use real design patterns from styles-catalog.md

## Simple Artifacts (No Builder Needed)
For single-file HTML/JSX artifacts without state management:
- Write directly as inline HTML + Tailwind
- Include CDN links for any libraries
- Keep self-contained in one file

## When to Use Builder vs Simple
| Scenario | Approach |
|---|---|
| Single interactive demo | Simple inline HTML |
| Multi-page app with routing | Web Artifacts Builder |
| Complex state management | Web Artifacts Builder |
| shadcn/ui components needed | Web Artifacts Builder |
| Quick visualization | Simple inline HTML |
| Dashboard with multiple views | Web Artifacts Builder |
