import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { disconnect } from './lib/ssh.js';
import { registerDeviceTools } from './tools/device.js';
import { registerInteractionTools } from './tools/interaction.js';
import { registerAppTools } from './tools/app.js';
import { registerScreenshotTools } from './tools/screenshot.js';
import { registerDebugTools } from './tools/debug.js';

const server = new McpServer({
  name: 'ios-simulator',
  version: '1.0.0',
});

// Register all tool groups
registerDeviceTools(server);
registerInteractionTools(server);
registerAppTools(server);
registerScreenshotTools(server);
registerDebugTools(server);

// Start the server with stdio transport
async function main(): Promise<void> {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('iOS Simulator MCP server running on stdio');
}

// Graceful shutdown
async function cleanup(): Promise<void> {
  await disconnect();
  process.exit(0);
}

process.on('SIGINT', cleanup);
process.on('SIGTERM', cleanup);

main().catch((err) => {
  console.error('Fatal error:', err);
  disconnect().finally(() => process.exit(1));
});
