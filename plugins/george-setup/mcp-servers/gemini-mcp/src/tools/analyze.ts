import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { getClient } from "../lib/client.js";
import { readFileAsBase64 } from "../lib/files.js";

export function registerAnalyzeTools(server: McpServer): void {
  server.registerTool(
    "gemini_analyze",
    {
      title: "Gemini Analyze File",
      description:
        "Analyze files (images, audio, video, PDFs) with Gemini 3.1 Pro. " +
        "Supports: images (png, jpg, gif, webp), audio (mp3, wav), video (mp4, mov, webm), and PDFs. " +
        "Example use cases: describe an image, transcribe audio, summarize a video, extract text from a PDF, " +
        "answer questions about visual content, analyze charts/diagrams, review UI screenshots, " +
        "or any other multimodal analysis task.",
      inputSchema: z
        .object({
          file_path: z
            .string()
            .describe(
              "Path to the file to analyze. Supports images (png, jpg, gif, webp), " +
                "audio (mp3, wav), video (mp4, mov, webm), and PDFs."
            ),
          prompt: z
            .string()
            .describe(
              'Analysis prompt/question about the file (e.g., "Describe this image", ' +
                '"Transcribe this audio", "Summarize this PDF")'
            ),
          system_instruction: z
            .string()
            .optional()
            .describe("System instruction to guide the model's behavior."),
        })
        .strict(),
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
      },
    },
    async (params) => {
      try {
        const ai = await getClient();
        const { data, mimeType } = readFileAsBase64(params.file_path);

        const config: any = {};
        if (params.system_instruction) {
          config.systemInstruction = params.system_instruction;
        }

        const response = await ai.models.generateContent({
          model: "gemini-3.1-pro-preview",
          contents: [
            {
              role: "user",
              parts: [
                { text: params.prompt },
                { inlineData: { data, mimeType } },
              ],
            },
          ],
          config,
        });

        return {
          content: [
            {
              type: "text" as const,
              text: response.text ?? "(empty response)",
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
              text: `Error analyzing file: ${message}`,
            },
          ],
        };
      }
    }
  );
}
