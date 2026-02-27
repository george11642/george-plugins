import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { getClient } from "../lib/client.js";

export function registerSearchTools(server: McpServer): void {
  server.registerTool(
    "gemini_search",
    {
      title: "Gemini Search (Grounded)",
      description:
        "Answer a question using Gemini with Google Search grounding. " +
        "The model will search the web for up-to-date information and cite its sources. " +
        "Use this for factual queries, current events, recent documentation, or any question " +
        "that benefits from real-time web data. Returns the answer along with source URLs.",
      inputSchema: z
        .object({
          query: z
            .string()
            .describe("The question to answer with Google Search grounding"),
          model: z
            .enum(["gemini-3.1-pro-preview", "gemini-3-flash-preview"])
            .optional()
            .default("gemini-3.1-pro-preview")
            .describe(
              "Model to use. 'gemini-3.1-pro-preview' for highest quality (default), " +
                "'gemini-3-flash-preview' for faster responses."
            ),
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
        const response = await ai.models.generateContent({
          model: params.model,
          contents: params.query,
          config: {
            tools: [{ googleSearch: {} }],
          },
        });

        const answerText = response.text ?? "(empty response)";

        const groundingMetadata =
          response.candidates?.[0]?.groundingMetadata;

        let output = answerText;

        if (groundingMetadata) {
          const { webSearchQueries, groundingChunks } = groundingMetadata;

          if (webSearchQueries && webSearchQueries.length > 0) {
            output += "\n\n---\n**Search queries used:** " +
              webSearchQueries.join(", ");
          }

          if (groundingChunks && groundingChunks.length > 0) {
            output += "\n\n**Sources:**";
            for (const chunk of groundingChunks) {
              const web = chunk.web;
              if (web) {
                const title = web.title ?? "Untitled";
                const uri = web.uri ?? "";
                output += `\n- [${title}](${uri})`;
              }
            }
          }
        }

        return {
          content: [
            {
              type: "text" as const,
              text: output,
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
              text: `Error calling Gemini Search: ${message}`,
            },
          ],
        };
      }
    }
  );
}
