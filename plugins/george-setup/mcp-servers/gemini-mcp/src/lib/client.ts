import { GoogleGenAI } from "@google/genai";
import { readFileSync, writeFileSync } from "fs";
import { homedir } from "os";
import { join } from "path";

const CREDS_PATH = join(homedir(), ".gemini", "oauth_creds.json");
// These are the Gemini CLI's public OAuth values. Read from env vars or
// the creds file — run `gemini auth login` to populate ~/.gemini/oauth_creds.json.
const GEMINI_CLIENT_ID = process.env.GEMINI_CLIENT_ID ?? "";
const GEMINI_CLIENT_SECRET = process.env.GEMINI_CLIENT_SECRET ?? "";
const CODE_ASSIST_ENDPOINT = "https://cloudcode-pa.googleapis.com";
const CODE_ASSIST_VERSION = "v1internal";

interface OAuthCreds {
  access_token: string;
  refresh_token: string;
  client_id?: string;
  client_secret?: string;
  expiry_date: number;
}

function loadCreds(): OAuthCreds | null {
  try {
    return JSON.parse(readFileSync(CREDS_PATH, "utf-8"));
  } catch {
    return null;
  }
}

const nativeFetch = globalThis.fetch;

async function refreshAccessToken(creds: OAuthCreds): Promise<OAuthCreds> {
  const res = await nativeFetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: creds.client_id || GEMINI_CLIENT_ID,
      client_secret: creds.client_secret || GEMINI_CLIENT_SECRET,
      refresh_token: creds.refresh_token,
      grant_type: "refresh_token",
    }),
  });
  if (!res.ok) throw new Error(`Token refresh failed: ${res.status}`);
  const data = (await res.json()) as { access_token: string; expires_in: number };
  const updated: OAuthCreds = {
    ...creds,
    access_token: data.access_token,
    expiry_date: Date.now() + data.expires_in * 1000,
  };
  writeFileSync(CREDS_PATH, JSON.stringify(updated, null, 2));
  return updated;
}

async function getAccessToken(): Promise<string> {
  let creds = loadCreds();
  if (!creds) throw new Error("No OAuth credentials found");
  if (Date.now() >= creds.expiry_date - 60_000) {
    creds = await refreshAccessToken(creds);
  }
  return creds.access_token;
}

// Companion project ID — fetched once via loadCodeAssist, cached in memory
let companionProject: string | null = null;

async function getCompanionProject(token: string): Promise<string> {
  if (companionProject) return companionProject;

  const res = await nativeFetch(
    `${CODE_ASSIST_ENDPOINT}/${CODE_ASSIST_VERSION}:loadCodeAssist`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        metadata: {
          ideType: "IDE_UNSPECIFIED",
          platform: "PLATFORM_UNSPECIFIED",
          pluginType: "GEMINI",
        },
      }),
    },
  );

  if (!res.ok) {
    throw new Error(`loadCodeAssist failed: ${res.status} ${await res.text()}`);
  }

  const data = (await res.json()) as Record<string, unknown>;
  const proj = data.cloudaicompanionProject;
  const projectId =
    typeof proj === "string"
      ? proj
      : (proj as Record<string, unknown> | undefined)?.id;

  if (typeof projectId !== "string" || !projectId) {
    throw new Error("No companion project returned by loadCodeAssist");
  }

  companionProject = projectId;
  return projectId;
}

let interceptorInstalled = false;

function installFetchInterceptor(): void {
  if (interceptorInstalled) return;
  interceptorInstalled = true;

  globalThis.fetch = async function (
    input: string | Request | URL,
    init?: RequestInit,
  ): Promise<Response> {
    const url =
      typeof input === "string"
        ? input
        : input instanceof URL
          ? input.toString()
          : (input as Request).url;

    // Only intercept Gemini API requests
    if (!url.includes("generativelanguage.googleapis.com")) {
      return nativeFetch(input, init);
    }

    // Extract model and action: /models/{model}:{action}
    const match = url.match(/\/models\/([^:]+):(\w+)/);
    if (!match) return nativeFetch(input, init);

    const [, model, action] = match;

    // Image models are not supported by Code Assist proxy (returns 400:
    // "Multi-modal output is not supported"). Use GEMINI_API_KEY for direct access.
    if (model.includes("image")) {
      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey) {
        throw new Error(
          "Image generation requires GEMINI_API_KEY. The Code Assist OAuth proxy " +
          "does not support image models. Get a free key at https://aistudio.google.com/apikey"
        );
      }
      const headers = new Headers(init?.headers);
      headers.delete("x-goog-api-key");
      headers.set("x-goog-api-key", apiKey);
      const cleanUrl = url.replace(/[?&]key=OAUTH/, "");
      return nativeFetch(cleanUrl, { ...init, headers });
    }

    const queryIdx = url.indexOf("?");
    const query = queryIdx >= 0 ? url.slice(queryIdx) : "";
    const rewrittenUrl = `${CODE_ASSIST_ENDPOINT}/${CODE_ASSIST_VERSION}:${action}${query}`;

    const token = await getAccessToken();
    const project = await getCompanionProject(token);

    const headers = new Headers(init?.headers);
    headers.delete("x-goog-api-key");
    headers.set("Authorization", `Bearer ${token}`);

    // Wrap body in Code Assist format: {model, project, request: <original body>}
    let body = init?.body;
    if (body && typeof body === "string") {
      try {
        const parsed = JSON.parse(body);
        const wrapped: Record<string, unknown> =
          action === "countTokens"
            ? { request: { model: `models/${model}`, ...parsed } }
            : { model, project, request: parsed };
        body = JSON.stringify(wrapped);
      } catch {
        // Not JSON, send as-is
      }
    }

    const res = await nativeFetch(rewrittenUrl, { ...init, headers, body });

    // Unwrap Code Assist response: { response: {...} } → {...}
    // The SDK expects the inner object (candidates, usageMetadata, etc.)
    if (res.ok && !query.includes("alt=sse")) {
      const json = await res.json();
      const inner = (json as Record<string, unknown>).response ?? json;
      return new Response(JSON.stringify(inner), {
        status: res.status,
        statusText: res.statusText,
        headers: res.headers,
      });
    }

    return res;
  };
}

export async function getClient(): Promise<GoogleGenAI> {
  // Try OAuth via Code Assist endpoint (gemini-cli tokens)
  const creds = loadCreds();
  if (creds?.refresh_token) {
    installFetchInterceptor();
    return new GoogleGenAI({ apiKey: "OAUTH" });
  }

  // Fallback to API key
  const apiKey = process.env.GEMINI_API_KEY;
  if (apiKey) {
    return new GoogleGenAI({ apiKey });
  }

  throw new Error(
    "No authentication available. Run 'gemini' CLI to log in with Google, " +
    "or set GEMINI_API_KEY environment variable."
  );
}
