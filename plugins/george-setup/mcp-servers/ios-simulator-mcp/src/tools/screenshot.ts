import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import * as simctl from '../lib/simctl.js';

export function registerScreenshotTools(server: McpServer): void {
  server.tool(
    'ios_screenshot',
    'Capture a screenshot of the iOS Simulator screen. Returns a base64-encoded PNG image that Claude can see and analyze.',
    {
      udid: z.string().optional().describe('Device UDID. Omit to use booted device.'),
    },
    async ({ udid }) => {
      try {
        const targetUdid = await simctl.resolveUdid(udid);
        const buffer = await simctl.screenshot(targetUdid);

        return {
          content: [
            {
              type: 'image' as const,
              data: buffer.toString('base64'),
              mimeType: 'image/png',
            },
          ],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error capturing screenshot: ${err}` }],
          isError: true,
        };
      }
    }
  );
}
