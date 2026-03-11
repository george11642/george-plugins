---
name: browser-agent
description: "Use when automating Chrome browser interactions, taking screenshots, filling forms, or verifying UI visually. Triggers on browser automation, take screenshot, screenshot page, fill form, click button, navigate to URL, Chrome DevTools, use_browser, visual verification, desktop and mobile screenshot, OAuth flow in browser, email verification flow, extract page content, DOM inspection, multi-tab browsing, form submit, CSS selector, headless Chrome, browser profile, login flow, signup flow."
allowed-tools: mcp__plugin_superpowers-chrome_chrome__use_browser
---

# Browser Agent

Control Chrome via DevTools Protocol using the `use_browser` MCP tool.

## Loading

```
ToolSearch: select:mcp__plugin_superpowers-chrome_chrome__use_browser
```

## Tool Parameters

- `action` (required): Operation to perform
- `tab_index` (optional): Tab to operate on (default: 0)
- `selector` (optional): CSS selector for element operations
- `payload` (optional): Action-specific data
- `timeout` (optional): Timeout in ms (default: 5000)

## Actions Quick Reference

| Category | Action | Key Params |
|----------|--------|------------|
| Navigate | `navigate` | payload: URL |
| Wait | `await_element` | selector, timeout |
| Wait | `await_text` | payload: text string |
| Click | `click` | selector |
| Type | `type` | selector, payload (append `\n` to submit) |
| Select | `select` | selector, payload: option value |
| Extract | `extract` | payload: 'markdown'\|'text'\|'html', selector (opt) |
| Attribute | `attr` | selector, payload: attribute name |
| JS | `eval` | payload: JavaScript code |
| Screenshot | `screenshot` | payload: file path |
| Tabs | `list_tabs`, `new_tab`, `close_tab` | tab_index |
| Mode | `show_browser`, `hide_browser`, `browser_mode` | -- |
| Profile | `set_profile`, `get_profile` | payload: profile name |

## Critical Patterns

### Always Wait Before Interacting
```json
{"action": "navigate", "payload": "https://example.com"}
{"action": "await_element", "selector": "button.submit"}
{"action": "click", "selector": "button.submit"}
```

### Form Fill and Submit
```json
{"action": "type", "selector": "input[name=email]", "payload": "user@example.com"}
{"action": "type", "selector": "input[name=password]", "payload": "pass123\n"}
{"action": "await_text", "payload": "Welcome"}
```

### Reconnaissance-Then-Action
1. Navigate and wait for load
2. `{"action": "extract", "payload": "html"}` to inspect rendered DOM
3. Identify correct selectors from output
4. Execute actions with discovered selectors

### Visual Verification (Desktop + Mobile)
```json
{"action": "navigate", "payload": "https://myapp.com"}
{"action": "await_element", "selector": "main"}
{"action": "screenshot", "payload": "/tmp/desktop.png"}
{"action": "eval", "payload": "window.innerWidth = 375; window.innerHeight = 812;"}
{"action": "screenshot", "payload": "/tmp/mobile.png"}
```

### OAuth / Email Verification
1. Fill signup form, submit
2. `{"action": "new_tab"}` then navigate to email provider
3. Find verification email, click link
4. `{"action": "await_text", "payload": "verified"}`

### Multi-Tab
```json
{"action": "list_tabs"}
{"action": "extract", "tab_index": 1, "payload": "text", "selector": ".content"}
```

## Gotchas

- **Headless by default** -- screenshots work fine, no need to switch
- **show_browser/hide_browser restarts Chrome** -- loses POST state, JS state; tabs reload via GET
- **Use specific selectors** -- `button[type=submit]` not `button`
- **JS returns** -- wrap complex objects in `JSON.stringify()` to avoid `[object Object]`
- **Profile persists** -- cookies/auth survive mode toggles and restarts
- **Slow pages** -- increase timeout: `{"timeout": 30000}`
- **Submit with \\n** -- append `\n` to payload to submit forms: `"password\n"`

## When to Use This vs Playwright

| This (use_browser MCP) | Playwright (webapp-testing skill) |
|---|---|
| Authenticated sessions | Fresh browser instances |
| Quick interactions | Full E2E test suites |
| Existing browser tabs | PDF generation pipelines |
| Simple form fills | Complex multi-step tests |
