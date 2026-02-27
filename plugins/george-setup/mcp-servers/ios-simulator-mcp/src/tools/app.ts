import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import * as simctl from '../lib/simctl.js';

export function registerAppTools(server: McpServer): void {
  server.tool(
    'ios_install_app',
    'Install an app on the iOS Simulator from a .app bundle path on the macOS VM',
    {
      app_path: z.string().describe('Path to the .app bundle on the macOS VM'),
      udid: z.string().optional().describe('Device UDID. Omit to use booted device.'),
    },
    async ({ app_path, udid }) => {
      try {
        const targetUdid = await simctl.resolveUdid(udid);
        await simctl.install(targetUdid, app_path);
        return {
          content: [
            { type: 'text', text: `App installed from "${app_path}" on device ${targetUdid}.` },
          ],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error installing app: ${err}` }],
          isError: true,
        };
      }
    }
  );

  server.tool(
    'ios_launch_app',
    'Launch an installed app by bundle ID on the iOS Simulator',
    {
      bundle_id: z.string().describe('Bundle identifier of the app to launch'),
      udid: z.string().optional().describe('Device UDID. Omit to use booted device.'),
    },
    async ({ bundle_id, udid }) => {
      try {
        const targetUdid = await simctl.resolveUdid(udid);
        await simctl.launch(targetUdid, bundle_id);
        return {
          content: [
            { type: 'text', text: `App ${bundle_id} launched on device ${targetUdid}.` },
          ],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error launching app: ${err}` }],
          isError: true,
        };
      }
    }
  );

  server.tool(
    'ios_terminate_app',
    'Terminate a running app by bundle ID on the iOS Simulator',
    {
      bundle_id: z.string().describe('Bundle identifier of the app to terminate'),
      udid: z.string().optional().describe('Device UDID. Omit to use booted device.'),
    },
    async ({ bundle_id, udid }) => {
      try {
        const targetUdid = await simctl.resolveUdid(udid);
        await simctl.terminate(targetUdid, bundle_id);
        return {
          content: [
            { type: 'text', text: `App ${bundle_id} terminated on device ${targetUdid}.` },
          ],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error terminating app: ${err}` }],
          isError: true,
        };
      }
    }
  );

  server.tool(
    'ios_uninstall_app',
    'Uninstall an app by bundle ID from the iOS Simulator',
    {
      bundle_id: z.string().describe('Bundle identifier of the app to uninstall'),
      udid: z.string().optional().describe('Device UDID. Omit to use booted device.'),
    },
    async ({ bundle_id, udid }) => {
      try {
        const targetUdid = await simctl.resolveUdid(udid);
        await simctl.uninstall(targetUdid, bundle_id);
        return {
          content: [
            { type: 'text', text: `App ${bundle_id} uninstalled from device ${targetUdid}.` },
          ],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error uninstalling app: ${err}` }],
          isError: true,
        };
      }
    }
  );

  server.tool(
    'ios_list_apps',
    'List all installed apps on the iOS Simulator',
    {
      udid: z.string().optional().describe('Device UDID. Omit to use booted device.'),
    },
    async ({ udid }) => {
      try {
        const targetUdid = await simctl.resolveUdid(udid);
        const appList = await simctl.getAppList(targetUdid);
        return {
          content: [{ type: 'text', text: appList || 'No apps found.' }],
        };
      } catch (err) {
        return {
          content: [{ type: 'text', text: `Error listing apps: ${err}` }],
          isError: true,
        };
      }
    }
  );
}
