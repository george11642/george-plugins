import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import * as simctl from '../lib/simctl.js';

export function registerDeviceTools(server: McpServer): void {
  server.tool(
    'ios_list_devices',
    'List all iOS Simulator devices with their UDID, state, and runtime',
    {},
    async () => {
      try {
        const data = await simctl.list();
        const lines: string[] = [];

        lines.push('=== Runtimes ===');
        for (const rt of data.runtimes) {
          const status = rt.isAvailable ? 'available' : 'unavailable';
          lines.push(`  ${rt.name} (${rt.identifier}) [${status}]`);
        }

        lines.push('');
        lines.push('=== Devices ===');
        for (const [runtime, devices] of Object.entries(data.devices)) {
          if (devices.length === 0) continue;
          lines.push(`  ${runtime}:`);
          for (const d of devices) {
            const avail = d.isAvailable ? '' : ' [unavailable]';
            lines.push(`    ${d.name} | ${d.udid} | ${d.state}${avail}`);
          }
        }

        return { content: [{ type: 'text', text: lines.join('\n') }] };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error listing devices: ${err}` }],
          isError: true,
        };
      }
    }
  );

  server.tool(
    'ios_boot_device',
    'Boot an iOS Simulator device. If no UDID given, boots the first available device.',
    { udid: z.string().optional().describe('Device UDID. Omit to boot first available.') },
    async ({ udid }) => {
      try {
        let targetUdid = udid;
        if (!targetUdid) {
          const data = await simctl.list();
          for (const devices of Object.values(data.devices)) {
            for (const d of devices) {
              if (d.isAvailable && d.state === 'Shutdown') {
                targetUdid = d.udid;
                break;
              }
            }
            if (targetUdid) break;
          }
          if (!targetUdid) {
            return {
              content: [{ type: 'text', text: 'No available shutdown device found to boot.' }],
              isError: true,
            };
          }
        }

        await simctl.boot(targetUdid);
        return {
          content: [{ type: 'text', text: `Device ${targetUdid} booted successfully.` }],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error booting device: ${err}` }],
          isError: true,
        };
      }
    }
  );

  server.tool(
    'ios_shutdown_device',
    'Shutdown an iOS Simulator device. If no UDID given, shuts down the currently booted device.',
    { udid: z.string().optional().describe('Device UDID. Omit to shutdown booted device.') },
    async ({ udid }) => {
      try {
        const targetUdid = await simctl.resolveUdid(udid);
        await simctl.shutdown(targetUdid);
        return {
          content: [{ type: 'text', text: `Device ${targetUdid} shut down successfully.` }],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error shutting down device: ${err}` }],
          isError: true,
        };
      }
    }
  );

  server.tool(
    'ios_create_device',
    'Create a new iOS Simulator device and return its UDID',
    {
      name: z.string().describe('Name for the new device'),
      device_type: z.string().default('iPhone 15').describe('Device type (e.g. "iPhone 15")'),
      runtime: z
        .string()
        .default('com.apple.CoreSimulator.SimRuntime.iOS-17-2')
        .describe('Runtime identifier'),
    },
    async ({ name, device_type, runtime }) => {
      try {
        const newUdid = await simctl.create(name, device_type, runtime);
        return {
          content: [
            { type: 'text', text: `Device created successfully.\nName: ${name}\nUDID: ${newUdid}` },
          ],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error creating device: ${err}` }],
          isError: true,
        };
      }
    }
  );

  server.tool(
    'ios_delete_device',
    'Delete an iOS Simulator device',
    { udid: z.string().describe('UDID of the device to delete') },
    async ({ udid }) => {
      try {
        await simctl.deleteDevice(udid);
        return {
          content: [{ type: 'text', text: `Device ${udid} deleted successfully.` }],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error deleting device: ${err}` }],
          isError: true,
        };
      }
    }
  );
}
