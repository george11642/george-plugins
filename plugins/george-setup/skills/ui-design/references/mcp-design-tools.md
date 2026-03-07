# MCP Design Tools

## Available MCPs for Design Work

### Stitch (Mockups & Wireframes)
- Use `ToolSearch` to discover Stitch MCP tools
- Generate UI mockups and wireframes programmatically
- Useful for rapid prototyping before implementation
- Output: visual mockups for review with stakeholders

### Gemini (Image Generation & Editing)
- `gemini_image` — generate images from text prompts
- `gemini_image_fast` — quick image generation
- `gemini_image_edit` — edit existing images with prompts
- Use for: hero images, backgrounds, illustrations, icons
- Pair with design system colors for brand consistency

### Figma MCP (Design Specs)
- Use `ToolSearch` to discover Figma MCP tools if available
- Extract design tokens, spacing, colors from Figma files
- Read component specs for pixel-perfect implementation
- Bridge between design and development

### LaTeX MCP (Scientific Visuals)
- `create_latex_file` — create LaTeX documents
- `edit_latex_file` — modify existing LaTeX
- `validate_latex` — check for errors
- Use for: scientific posters, mathematical typesetting, conference materials

### Superpowers Chrome (UI Verification)
- `use_browser` — interact with browser for visual testing
- Screenshot pages to verify implementation matches design
- Test responsive breakpoints visually
- Verify accessibility in real browser context

## MCP Usage Pattern
1. Always use `ToolSearch` first to discover available tools
2. MCPs change frequently — never hardcode tool names
3. All MCP calls should go through agents (context-heavy)
4. Combine MCPs: Gemini for assets → implementation → Chrome for verification
