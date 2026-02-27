#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { registerChatTools } from "./tools/chat.js";
import { registerImageTools } from "./tools/image.js";
import { registerVideoTools } from "./tools/video.js";
import { registerTtsTools } from "./tools/tts.js";
import { registerAnalyzeTools } from "./tools/analyze.js";
import { registerCodeTools } from "./tools/code.js";
import { registerSearchTools } from "./tools/search.js";
import { registerEmbedTools } from "./tools/embed.js";

const server = new McpServer({
  name: "gemini-mcp-server",
  version: "1.0.0",
});

// Register all tools
registerChatTools(server);
registerImageTools(server);
registerVideoTools(server);
registerTtsTools(server);
registerAnalyzeTools(server);
registerCodeTools(server);
registerSearchTools(server);
registerEmbedTools(server);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Gemini MCP server running via stdio (12 tools registered)");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
