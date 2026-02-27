import * as fs from "fs";
import * as path from "path";
import * as os from "os";

// Use GEMINI_OUTPUT_DIR if set (for Windows: /mnt/c/Users/.../gemini-output),
// otherwise default to ~/gemini-output
const OUTPUT_BASE = process.env.GEMINI_OUTPUT_DIR || path.join(os.homedir(), "gemini-output");

function ensureDir(dir: string): void {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function timestamp(): string {
  return new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
}

/**
 * Convert a WSL /mnt/X/ path to a Windows X:\ path for display.
 * If the path isn't under /mnt/, returns as-is.
 */
function toDisplayPath(wslPath: string): string {
  const match = wslPath.match(/^\/mnt\/([a-z])\/(.*)/);
  if (!match) return wslPath;
  const [, drive, rest] = match;
  return `${drive.toUpperCase()}:\\${rest.replace(/\//g, "\\")}`;
}

export function saveImage(base64Data: string, prefix = "image"): string {
  const dir = path.join(OUTPUT_BASE, "images");
  ensureDir(dir);
  const filePath = path.join(dir, `${prefix}-${timestamp()}.png`);
  fs.writeFileSync(filePath, Buffer.from(base64Data, "base64"));
  return toDisplayPath(filePath);
}

export function saveAudio(pcmData: Buffer, prefix = "tts"): string {
  const dir = path.join(OUTPUT_BASE, "audio");
  ensureDir(dir);
  const filePath = path.join(dir, `${prefix}-${timestamp()}.wav`);

  // Write WAV header + PCM data (16-bit, 24kHz, mono)
  const sampleRate = 24000;
  const numChannels = 1;
  const bitsPerSample = 16;
  const byteRate = sampleRate * numChannels * (bitsPerSample / 8);
  const blockAlign = numChannels * (bitsPerSample / 8);
  const dataSize = pcmData.length;

  const header = Buffer.alloc(44);
  header.write("RIFF", 0);
  header.writeUInt32LE(36 + dataSize, 4);
  header.write("WAVE", 8);
  header.write("fmt ", 12);
  header.writeUInt32LE(16, 16); // PCM chunk size
  header.writeUInt16LE(1, 20);  // PCM format
  header.writeUInt16LE(numChannels, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(blockAlign, 32);
  header.writeUInt16LE(bitsPerSample, 34);
  header.write("data", 36);
  header.writeUInt32LE(dataSize, 40);

  fs.writeFileSync(filePath, Buffer.concat([header, pcmData]));
  return toDisplayPath(filePath);
}

export function saveVideo(data: Buffer, prefix = "video"): string {
  const dir = path.join(OUTPUT_BASE, "videos");
  ensureDir(dir);
  const filePath = path.join(dir, `${prefix}-${timestamp()}.mp4`);
  fs.writeFileSync(filePath, data);
  return toDisplayPath(filePath);
}

export function readFileAsBase64(filePath: string): { data: string; mimeType: string } {
  // Accept both Windows paths (C:\...) and WSL paths
  let resolvedPath = filePath;
  if (/^[A-Za-z]:\\/.test(filePath)) {
    // Convert Windows path to WSL: C:\foo\bar → /mnt/c/foo/bar
    const drive = filePath[0].toLowerCase();
    resolvedPath = `/mnt/${drive}/${filePath.slice(3).replace(/\\/g, "/")}`;
  } else if (filePath.startsWith("~")) {
    resolvedPath = path.join(os.homedir(), filePath.slice(1));
  } else {
    resolvedPath = path.resolve(filePath);
  }

  if (!fs.existsSync(resolvedPath)) {
    throw new Error(`File not found: ${resolvedPath}`);
  }

  const data = fs.readFileSync(resolvedPath).toString("base64");
  const ext = path.extname(resolvedPath).toLowerCase();

  const mimeMap: Record<string, string> = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".pdf": "application/pdf",
    ".mp3": "audio/mp3",
    ".wav": "audio/wav",
    ".mp4": "video/mp4",
    ".mov": "video/quicktime",
    ".avi": "video/x-msvideo",
    ".webm": "video/webm",
  };

  return { data, mimeType: mimeMap[ext] || "application/octet-stream" };
}
