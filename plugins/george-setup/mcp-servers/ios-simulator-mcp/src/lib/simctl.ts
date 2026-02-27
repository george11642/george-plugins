import { execCommand, execCommandRaw } from './ssh.js';

// --- Type Definitions ---

export interface SimDevice {
  name: string;
  udid: string;
  state: string;
  isAvailable: boolean;
  availabilityError?: string;
  dataPath?: string;
  logPath?: string;
}

export interface SimRuntime {
  name: string;
  identifier: string;
  version: string;
  buildversion: string;
  isAvailable: boolean;
}

export interface SimDeviceType {
  name: string;
  identifier: string;
  minRuntimeVersion?: number;
  maxRuntimeVersion?: number;
}

export interface SimctlList {
  devices: Record<string, SimDevice[]>;
  runtimes: SimRuntime[];
  devicetypes: SimDeviceType[];
}

// --- Device Management ---

export async function list(): Promise<SimctlList> {
  const result = await execCommand('xcrun simctl list -j');
  if (result.code !== 0) {
    throw new Error(`simctl list failed: ${result.stderr}`);
  }
  return JSON.parse(result.stdout) as SimctlList;
}

export async function getBootedDeviceId(): Promise<string | null> {
  const data = await list();
  for (const runtime of Object.keys(data.devices)) {
    for (const device of data.devices[runtime]) {
      if (device.state === 'Booted') {
        return device.udid;
      }
    }
  }
  return null;
}

export async function resolveUdid(udid?: string): Promise<string> {
  if (udid) return udid;
  const booted = await getBootedDeviceId();
  if (!booted) {
    throw new Error('No booted device found. Provide a UDID or boot a device first.');
  }
  return booted;
}

export async function boot(udid: string): Promise<void> {
  const result = await execCommand(`xcrun simctl boot ${udid}`);
  if (result.code !== 0 && !result.stderr.includes('current state: Booted')) {
    throw new Error(`Failed to boot device ${udid}: ${result.stderr}`);
  }
}

export async function shutdown(udid: string): Promise<void> {
  const result = await execCommand(`xcrun simctl shutdown ${udid}`);
  if (result.code !== 0 && !result.stderr.includes('current state: Shutdown')) {
    throw new Error(`Failed to shutdown device ${udid}: ${result.stderr}`);
  }
}

export async function create(
  name: string,
  deviceType: string,
  runtime: string
): Promise<string> {
  const result = await execCommand(
    `xcrun simctl create "${name}" "${deviceType}" "${runtime}"`
  );
  if (result.code !== 0) {
    throw new Error(`Failed to create device: ${result.stderr}`);
  }
  return result.stdout.trim();
}

export async function deleteDevice(udid: string): Promise<void> {
  const result = await execCommand(`xcrun simctl delete ${udid}`);
  if (result.code !== 0) {
    throw new Error(`Failed to delete device ${udid}: ${result.stderr}`);
  }
}

// --- Screenshots ---

export async function screenshot(udid: string): Promise<Buffer> {
  const tmpPath = '/tmp/mcp_screenshot.png';

  const captureResult = await execCommand(
    `xcrun simctl io ${udid} screenshot ${tmpPath}`
  );
  if (captureResult.code !== 0) {
    throw new Error(`Screenshot capture failed: ${captureResult.stderr}`);
  }

  const buffer = await execCommandRaw(`cat ${tmpPath}`);

  await execCommand(`rm -f ${tmpPath}`);

  return buffer;
}

// --- App Management ---

export async function install(udid: string, appPath: string): Promise<void> {
  const result = await execCommand(`xcrun simctl install ${udid} "${appPath}"`);
  if (result.code !== 0) {
    throw new Error(`Failed to install app: ${result.stderr}`);
  }
}

export async function launch(udid: string, bundleId: string): Promise<void> {
  const result = await execCommand(
    `xcrun simctl launch ${udid} ${bundleId}`
  );
  if (result.code !== 0) {
    throw new Error(`Failed to launch app ${bundleId}: ${result.stderr}`);
  }
}

export async function terminate(udid: string, bundleId: string): Promise<void> {
  const result = await execCommand(
    `xcrun simctl terminate ${udid} ${bundleId}`
  );
  if (result.code !== 0) {
    throw new Error(`Failed to terminate app ${bundleId}: ${result.stderr}`);
  }
}

export async function uninstall(udid: string, bundleId: string): Promise<void> {
  const result = await execCommand(
    `xcrun simctl uninstall ${udid} ${bundleId}`
  );
  if (result.code !== 0) {
    throw new Error(`Failed to uninstall app ${bundleId}: ${result.stderr}`);
  }
}

export async function getAppList(udid: string): Promise<string> {
  const result = await execCommand(
    `xcrun simctl listapps ${udid}`
  );
  if (result.code !== 0) {
    // Fallback: try the older command format
    const fallback = await execCommand(
      `xcrun simctl get_app_container ${udid} 2>&1 || xcrun simctl spawn ${udid} launchctl list`
    );
    return fallback.stdout || fallback.stderr;
  }
  return result.stdout;
}

// --- URL & Location ---

export async function openUrl(udid: string, url: string): Promise<void> {
  const result = await execCommand(
    `xcrun simctl openurl ${udid} "${url}"`
  );
  if (result.code !== 0) {
    throw new Error(`Failed to open URL: ${result.stderr}`);
  }
}

export async function setLocation(
  udid: string,
  lat: number,
  lon: number
): Promise<void> {
  const result = await execCommand(
    `xcrun simctl location ${udid} set ${lat},${lon}`
  );
  if (result.code !== 0) {
    throw new Error(`Failed to set location: ${result.stderr}`);
  }
}

// --- Push Notifications ---

export async function sendPushNotification(
  udid: string,
  bundleId: string,
  payload: object
): Promise<void> {
  const payloadJson = JSON.stringify(payload).replace(/'/g, "'\\''");
  const tmpPath = '/tmp/mcp_push_payload.json';

  await execCommand(`echo '${payloadJson}' > ${tmpPath}`);
  const result = await execCommand(
    `xcrun simctl push ${udid} ${bundleId} ${tmpPath}`
  );
  await execCommand(`rm -f ${tmpPath}`);

  if (result.code !== 0) {
    throw new Error(`Failed to send push notification: ${result.stderr}`);
  }
}

// --- Logs ---

export async function getLogs(udid: string, count = 100): Promise<string> {
  const result = await execCommand(
    `xcrun simctl spawn ${udid} log show --style compact --last ${count > 1000 ? 1000 : count}m 2>/dev/null | tail -n ${count}`,
    60000
  );
  if (result.code !== 0) {
    // Fallback: try system log
    const fallback = await execCommand(
      `tail -n ${count} ~/Library/Logs/CoreSimulator/${udid}/system.log 2>/dev/null || echo "No logs available"`
    );
    return fallback.stdout;
  }
  return result.stdout;
}

// --- UI Hierarchy ---

export async function getUITree(udid: string): Promise<string> {
  const result = await execCommand(
    `xcrun simctl ui ${udid} describe`
  );
  if (result.code !== 0) {
    throw new Error(`Failed to get UI tree: ${result.stderr}`);
  }
  return result.stdout;
}

// --- Interaction ---

export async function tap(udid: string, x: number, y: number): Promise<void> {
  const result = await execCommand(
    `xcrun simctl io ${udid} tap ${x} ${y}`
  );
  if (result.code !== 0) {
    throw new Error(`Failed to tap at (${x}, ${y}): ${result.stderr}`);
  }
}

export async function swipe(
  udid: string,
  fromX: number,
  fromY: number,
  toX: number,
  toY: number,
  duration = 0.5
): Promise<void> {
  const result = await execCommand(
    `xcrun simctl io ${udid} swipe ${fromX} ${fromY} ${toX} ${toY} --duration ${duration}`
  );
  if (result.code !== 0) {
    throw new Error(
      `Failed to swipe from (${fromX},${fromY}) to (${toX},${toY}): ${result.stderr}`
    );
  }
}

export async function typeText(udid: string, text: string): Promise<void> {
  const escaped = text.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
  const result = await execCommand(
    `xcrun simctl io ${udid} type "${escaped}"`
  );
  if (result.code !== 0) {
    throw new Error(`Failed to type text: ${result.stderr}`);
  }
}

export async function pressButton(udid: string, button: string): Promise<void> {
  const buttonMap: Record<string, string> = {
    home: 'home',
    lock: 'lock',
    volumeUp: 'volumeUp',
    volumeDown: 'volumeDown',
  };

  const mappedButton = buttonMap[button];
  if (!mappedButton) {
    throw new Error(`Unknown button: ${button}. Valid: ${Object.keys(buttonMap).join(', ')}`);
  }

  const result = await execCommand(
    `xcrun simctl io ${udid} press ${mappedButton}`
  );
  if (result.code !== 0) {
    throw new Error(`Failed to press button ${button}: ${result.stderr}`);
  }
}
