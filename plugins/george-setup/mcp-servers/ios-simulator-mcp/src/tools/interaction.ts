import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import * as simctl from '../lib/simctl.js';

export function registerInteractionTools(server: McpServer): void {
  server.tool(
    'ios_tap',
    'Tap at a specific coordinate on the iOS Simulator screen',
    {
      x: z.number().describe('X coordinate to tap'),
      y: z.number().describe('Y coordinate to tap'),
      udid: z.string().optional().describe('Device UDID. Omit to use booted device.'),
    },
    async ({ x, y, udid }) => {
      try {
        const targetUdid = await simctl.resolveUdid(udid);
        await simctl.tap(targetUdid, x, y);
        return {
          content: [{ type: 'text', text: `Tapped at (${x}, ${y}) on device ${targetUdid}.` }],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error tapping: ${err}` }],
          isError: true,
        };
      }
    }
  );

  server.tool(
    'ios_type_text',
    'Type text into the currently focused field on the iOS Simulator',
    {
      text: z.string().describe('Text to type'),
      udid: z.string().optional().describe('Device UDID. Omit to use booted device.'),
    },
    async ({ text, udid }) => {
      try {
        const targetUdid = await simctl.resolveUdid(udid);
        await simctl.typeText(targetUdid, text);
        return {
          content: [{ type: 'text', text: `Typed "${text}" on device ${targetUdid}.` }],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error typing text: ${err}` }],
          isError: true,
        };
      }
    }
  );

  server.tool(
    'ios_swipe',
    'Perform a swipe gesture on the iOS Simulator screen',
    {
      from_x: z.number().describe('Starting X coordinate'),
      from_y: z.number().describe('Starting Y coordinate'),
      to_x: z.number().describe('Ending X coordinate'),
      to_y: z.number().describe('Ending Y coordinate'),
      duration: z.number().default(0.5).describe('Swipe duration in seconds'),
      udid: z.string().optional().describe('Device UDID. Omit to use booted device.'),
    },
    async ({ from_x, from_y, to_x, to_y, duration, udid }) => {
      try {
        const targetUdid = await simctl.resolveUdid(udid);
        await simctl.swipe(targetUdid, from_x, from_y, to_x, to_y, duration);
        return {
          content: [
            {
              type: 'text',
              text: `Swiped from (${from_x},${from_y}) to (${to_x},${to_y}) over ${duration}s on device ${targetUdid}.`,
            },
          ],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error swiping: ${err}` }],
          isError: true,
        };
      }
    }
  );

  server.tool(
    'ios_press_button',
    'Press a hardware button on the iOS Simulator',
    {
      button: z
        .enum(['home', 'lock', 'volumeUp', 'volumeDown'])
        .describe('Button to press'),
      udid: z.string().optional().describe('Device UDID. Omit to use booted device.'),
    },
    async ({ button, udid }) => {
      try {
        const targetUdid = await simctl.resolveUdid(udid);
        await simctl.pressButton(targetUdid, button);
        return {
          content: [{ type: 'text', text: `Pressed ${button} button on device ${targetUdid}.` }],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error pressing button: ${err}` }],
          isError: true,
        };
      }
    }
  );

  server.tool(
    'ios_open_url',
    'Open a URL on the iOS Simulator (launches in Safari or registered app)',
    {
      url: z.string().describe('URL to open'),
      udid: z.string().optional().describe('Device UDID. Omit to use booted device.'),
    },
    async ({ url, udid }) => {
      try {
        const targetUdid = await simctl.resolveUdid(udid);
        await simctl.openUrl(targetUdid, url);
        return {
          content: [{ type: 'text', text: `Opened URL "${url}" on device ${targetUdid}.` }],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error opening URL: ${err}` }],
          isError: true,
        };
      }
    }
  );

  server.tool(
    'ios_set_location',
    'Set the simulated GPS location on the iOS Simulator',
    {
      latitude: z.number().describe('Latitude'),
      longitude: z.number().describe('Longitude'),
      udid: z.string().optional().describe('Device UDID. Omit to use booted device.'),
    },
    async ({ latitude, longitude, udid }) => {
      try {
        const targetUdid = await simctl.resolveUdid(udid);
        await simctl.setLocation(targetUdid, latitude, longitude);
        return {
          content: [
            {
              type: 'text',
              text: `Location set to (${latitude}, ${longitude}) on device ${targetUdid}.`,
            },
          ],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error setting location: ${err}` }],
          isError: true,
        };
      }
    }
  );
}
