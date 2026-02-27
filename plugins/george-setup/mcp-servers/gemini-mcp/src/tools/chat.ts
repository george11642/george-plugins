import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { getClient } from "../lib/client.js";
import { getSession, setSession } from "../lib/sessions.js";

const THINKING_BUDGETS: Record<string, number> = {
  off: 0,
  low: 1024,
  medium: 8192,
  high: 32768,
};

function buildConfig(params: {
  system_instruction?: string;
  thinking?: string;
  temperature?: number;
  max_output_tokens?: number;
}) {
  const config: Record<string, unknown> = {
    temperature: params.temperature ?? 1,
    maxOutputTokens: params.max_output_tokens ?? 8192,
  };

  if (params.system_instruction) {
    config.systemInstruction = params.system_instruction;
  }

  const thinking = params.thinking ?? "off";
  if (thinking !== "off") {
    config.thinkingConfig = {
      thinkingBudget: THINKING_BUDGETS[thinking],
    };
  }

  return config;
}

const chatInputSchema = {
  message: z.string().describe("The message to send to Gemini"),
  session_id: z
    .string()
    .optional()
    .describe(
      "Session ID for multi-turn conversation. If provided and a session exists, continues the conversation. " +
        "If provided but no session exists, creates a new chat session and stores it under this ID. " +
        "If omitted, sends a one-shot request with no conversation history."
    ),
  system_instruction: z
    .string()
    .optional()
    .describe(
      "System instruction to guide the model's behavior. Only used when creating a new session or for one-shot requests. " +
        "Ignored when continuing an existing session."
    ),
  thinking: z
    .enum(["off", "low", "medium", "high"])
    .optional()
    .default("off")
    .describe(
      "Thinking/reasoning level. Controls how much internal reasoning the model performs before responding. " +
        "'off' = no thinking (default), 'low' = 1024 token budget, 'medium' = 8192 tokens, 'high' = 32768 tokens. " +
        "Higher levels improve quality on complex tasks but increase latency and token usage."
    ),
  temperature: z
    .number()
    .min(0)
    .max(2)
    .optional()
    .default(1)
    .describe(
      "Sampling temperature (0-2). Lower values make output more deterministic, higher values more creative. Default: 1."
    ),
  max_output_tokens: z
    .number()
    .optional()
    .default(8192)
    .describe("Maximum number of tokens in the response. Default: 8192."),
};

async function handleChat(
  model: string,
  params: {
    message: string;
    session_id?: string;
    system_instruction?: string;
    thinking?: string;
    temperature?: number;
    max_output_tokens?: number;
  }
): Promise<{ content: Array<{ type: "text"; text: string }> }> {
  try {
    const ai = await getClient();
    const config = buildConfig(params);
    let responseText: string | undefined;

    if (params.session_id) {
      const existingSession = getSession(params.session_id);

      if (existingSession) {
        const response = await existingSession.sendMessage({
          message: params.message,
        });
        responseText = response.text;
      } else {
        const chat = ai.chats.create({
          model,
          config,
        });
        const response = await chat.sendMessage({
          message: params.message,
        });
        setSession(params.session_id, chat);
        responseText = response.text;
      }
    } else {
      const response = await ai.models.generateContent({
        model,
        contents: params.message,
        config,
      });
      responseText = response.text;
    }

    return {
      content: [
        {
          type: "text" as const,
          text: responseText ?? "(empty response)",
        },
      ],
    };
  } catch (error) {
    const message =
      error instanceof Error ? error.message : String(error);
    return {
      content: [
        {
          type: "text" as const,
          text: `Error calling Gemini: ${message}`,
        },
      ],
    };
  }
}

export function registerChatTools(server: McpServer): void {
  server.registerTool(
    "gemini_chat",
    {
      title: "Gemini Chat (Pro)",
      description:
        "Send a message to Gemini 3.1 Pro Preview. Supports one-shot and multi-turn conversations. " +
        "Use this for complex reasoning, nuanced analysis, creative writing, and tasks requiring the highest quality output. " +
        "Provide a session_id to maintain conversation context across multiple calls. " +
        "Configure thinking level for enhanced reasoning on difficult problems. " +
        "Use gemini_chat_flash instead when speed is more important than quality.",
      inputSchema: z.object(chatInputSchema).strict(),
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
      },
    },
    async (params) => handleChat("gemini-3.1-pro-preview", params)
  );

  server.registerTool(
    "gemini_chat_flash",
    {
      title: "Gemini Chat (Flash)",
      description:
        "Send a message to Gemini 3.1 Flash Preview. Supports one-shot and multi-turn conversations. " +
        "Use this for fast responses, simple tasks, summarization, extraction, and high-throughput workloads. " +
        "Flash is significantly faster and cheaper than Pro while still delivering strong results. " +
        "Provide a session_id to maintain conversation context across multiple calls. " +
        "Configure thinking level for enhanced reasoning when needed. " +
        "Use gemini_chat instead when maximum quality is required.",
      inputSchema: z.object(chatInputSchema).strict(),
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
      },
    },
    async (params) => handleChat("gemini-3-flash-preview", params)
  );
}
