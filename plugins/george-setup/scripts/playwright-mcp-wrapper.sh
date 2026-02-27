#!/bin/bash
# Wrapper for Playwright MCP — launches its own headless browser (no CDP required).

exec npx @playwright/mcp@latest --headless
