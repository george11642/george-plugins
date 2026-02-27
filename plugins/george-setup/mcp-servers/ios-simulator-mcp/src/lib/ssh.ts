import { Client, ConnectConfig } from 'ssh2';

const config: ConnectConfig = {
  host: process.env.IOS_SSH_HOST || 'localhost',
  port: parseInt(process.env.IOS_SSH_PORT || '50922'),
  username: process.env.IOS_SSH_USER || 'user',
  password: process.env.IOS_SSH_PASS || 'alpine',
  readyTimeout: 10000,
};

let client: Client | null = null;
let connected = false;

function getClient(): Promise<Client> {
  return new Promise((resolve, reject) => {
    if (client && connected) {
      resolve(client);
      return;
    }

    if (client) {
      try { client.end(); } catch { /* ignore */ }
      client = null;
      connected = false;
    }

    client = new Client();

    client.on('ready', () => {
      connected = true;
      resolve(client!);
    });

    client.on('error', (err) => {
      connected = false;
      client = null;
      reject(err);
    });

    client.on('close', () => {
      connected = false;
      client = null;
    });

    client.connect(config);
  });
}

export async function execCommand(
  command: string,
  timeoutMs = 30000
): Promise<{ stdout: string; stderr: string; code: number }> {
  const conn = await getClient();
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error(`Command timed out after ${timeoutMs}ms`));
    }, timeoutMs);

    conn.exec(command, (err, stream) => {
      if (err) {
        clearTimeout(timer);
        reject(err);
        return;
      }

      let stdout = '';
      let stderr = '';

      stream.on('data', (data: Buffer) => {
        stdout += data.toString();
      });

      stream.stderr.on('data', (data: Buffer) => {
        stderr += data.toString();
      });

      stream.on('close', (code: number) => {
        clearTimeout(timer);
        resolve({
          stdout: stdout.trimEnd(),
          stderr: stderr.trimEnd(),
          code: code ?? 0,
        });
      });
    });
  });
}

export async function execCommandRaw(
  command: string,
  timeoutMs = 30000
): Promise<Buffer> {
  const conn = await getClient();
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error(`Command timed out after ${timeoutMs}ms`));
    }, timeoutMs);

    conn.exec(command, (err, stream) => {
      if (err) {
        clearTimeout(timer);
        reject(err);
        return;
      }

      const chunks: Buffer[] = [];

      stream.on('data', (data: Buffer) => {
        chunks.push(data);
      });

      stream.on('close', () => {
        clearTimeout(timer);
        resolve(Buffer.concat(chunks));
      });
    });
  });
}

export async function disconnect(): Promise<void> {
  if (client) {
    client.end();
    client = null;
    connected = false;
  }
}

process.on('exit', () => {
  if (client) client.end();
});

process.on('SIGINT', () => {
  if (client) client.end();
  process.exit();
});

process.on('SIGTERM', () => {
  if (client) client.end();
  process.exit();
});
