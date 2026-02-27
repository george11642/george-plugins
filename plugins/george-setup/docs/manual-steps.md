# Manual Setup Steps

These steps require API keys or credentials that can't be automated.

## 1. Gemini API Key (Required for gemini-mcp)

1. Go to [Google AI Studio](https://aistudio.google.com/apikey)
2. Create an API key
3. Add to `~/.claude/settings.json`:
   ```json
   {
     "env": {
       "GEMINI_API_KEY": "your-key-here"
     }
   }
   ```

## 2. Clerk (If Using Clerk Auth)

If your project uses Clerk:
1. Get your Clerk secret key from the [Clerk Dashboard](https://dashboard.clerk.com)
2. The clerk MCP server is available as an official plugin — install it:
   ```
   /plugin install clerk
   ```

## 3. Sentry (If Using Error Monitoring)

1. Install the Sentry plugin: `/plugin install sentry`
2. Follow its setup instructions for your Sentry org/project

## 4. Browser Automation (WSL2 Users)

If on WSL2, Chrome browser automation requires extra setup:
1. Install Chrome on Windows (not WSL)
2. The `resolve-wsl-chrome-host.sh` script (installed by `/george-setup:install`) handles host resolution
3. Run `~/.claude/scripts/patch-chrome-plugin-configs.sh` to configure browser plugins for WSL2

## 5. LaTeX (For latex-mcp)

Ensure LaTeX is installed:
- **macOS**: `brew install --cask mactex`
- **Ubuntu/WSL**: `sudo apt install texlive-full`
- **Arch**: `sudo pacman -S texlive-most`

## 6. Customize Your CLAUDE.md

After installation, edit `~/.claude/CLAUDE.md`:
1. Update the "About Me" section with your preferences
2. Add project-specific instructions as needed
3. The orchestration engine section should generally be kept as-is
