import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import * as simctl from '../lib/simctl.js';
import { execCommand } from '../lib/ssh.js';

export function registerDebugTools(server: McpServer): void {
  server.tool(
    'ios_get_logs',
    'Get recent logs from the iOS Simulator device',
    {
      udid: z.string().optional().describe('Device UDID. Omit to use booted device.'),
      lines: z.number().default(100).describe('Number of log lines to retrieve (max 1000)'),
    },
    async ({ udid, lines }) => {
      try {
        const targetUdid = await simctl.resolveUdid(udid);
        const logs = await simctl.getLogs(targetUdid, lines);
        return {
          content: [{ type: 'text', text: logs || 'No logs available.' }],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error getting logs: ${err}` }],
          isError: true,
        };
      }
    }
  );

  server.tool(
    'ios_ui_tree',
    'Get the accessibility UI hierarchy of the current screen on the iOS Simulator. Useful for finding elements to tap or interact with.',
    {
      udid: z.string().optional().describe('Device UDID. Omit to use booted device.'),
    },
    async ({ udid }) => {
      try {
        const targetUdid = await simctl.resolveUdid(udid);
        const tree = await simctl.getUITree(targetUdid);
        return {
          content: [{ type: 'text', text: tree || 'No UI tree available.' }],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error getting UI tree: ${err}` }],
          isError: true,
        };
      }
    }
  );

  server.tool(
    'ios_device_status',
    'Get comprehensive status of the iOS Simulator environment: booted devices, available runtimes, and disk space',
    {},
    async () => {
      try {
        const lines: string[] = [];

        // Get device list
        const data = await simctl.list();

        // Booted devices
        lines.push('=== Booted Devices ===');
        let bootedCount = 0;
        for (const [runtime, devices] of Object.entries(data.devices)) {
          for (const d of devices) {
            if (d.state === 'Booted') {
              lines.push(`  ${d.name} | ${d.udid} | ${runtime}`);
              bootedCount++;
            }
          }
        }
        if (bootedCount === 0) {
          lines.push('  (none)');
        }

        // Available runtimes
        lines.push('');
        lines.push('=== Available Runtimes ===');
        for (const rt of data.runtimes) {
          if (rt.isAvailable) {
            lines.push(`  ${rt.name} (${rt.identifier})`);
          }
        }

        // Disk space
        lines.push('');
        lines.push('=== Disk Space ===');
        const diskResult = await execCommand('df -h / 2>/dev/null | tail -1');
        if (diskResult.code === 0 && diskResult.stdout) {
          lines.push(`  ${diskResult.stdout}`);
        } else {
          lines.push('  (unable to retrieve)');
        }

        return {
          content: [{ type: 'text', text: lines.join('\n') }],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error getting device status: ${err}` }],
          isError: true,
        };
      }
    }
  );

  server.tool(
    'ios_send_push',
    'Send a push notification to an app on the iOS Simulator',
    {
      bundle_id: z.string().describe('Bundle identifier of the target app'),
      title: z.string().describe('Notification title'),
      body: z.string().describe('Notification body text'),
      udid: z.string().optional().describe('Device UDID. Omit to use booted device.'),
    },
    async ({ bundle_id, title, body, udid }) => {
      try {
        const targetUdid = await simctl.resolveUdid(udid);

        const payload = {
          aps: {
            alert: {
              title,
              body,
            },
            sound: 'default',
          },
        };

        await simctl.sendPushNotification(targetUdid, bundle_id, payload);
        return {
          content: [
            {
              type: 'text',
              text: `Push notification sent to ${bundle_id} on device ${targetUdid}.\nTitle: ${title}\nBody: ${body}`,
            },
          ],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error sending push notification: ${err}` }],
          isError: true,
        };
      }
    }
  );
}
