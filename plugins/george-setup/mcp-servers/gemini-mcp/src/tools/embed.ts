import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { getClient } from "../lib/client.js";

export function registerEmbedTools(server: McpServer): void {
  server.registerTool(
    "gemini_embed",
    {
      title: "Gemini Embed",
      description:
        "Generate text embeddings using Gemini's text-embedding-004 model. " +
        "Accepts up to 100 texts and returns dense vector embeddings for each. " +
        "Useful for semantic search, clustering, classification, and similarity comparisons. " +
        "Optionally specify a task type to optimize the embeddings for your use case, " +
        "and output dimensions to control vector size.",
      inputSchema: z
        .object({
          texts: z
            .array(z.string())
            .min(1)
            .max(100)
            .describe("Texts to generate embeddings for"),
          task_type: z
            .enum([
              "RETRIEVAL_QUERY",
              "RETRIEVAL_DOCUMENT",
              "SEMANTIC_SIMILARITY",
              "CLASSIFICATION",
              "CLUSTERING",
            ])
            .optional()
            .describe(
              "Type of embedding task for optimization. " +
                "'RETRIEVAL_QUERY' for search queries, 'RETRIEVAL_DOCUMENT' for documents to be searched, " +
                "'SEMANTIC_SIMILARITY' for comparing text similarity, " +
                "'CLASSIFICATION' for text classification, 'CLUSTERING' for grouping texts."
            ),
          dimensions: z
            .number()
            .int()
            .min(1)
            .max(768)
            .optional()
            .describe(
              "Output embedding dimensions (1-768). Lower dimensions reduce storage and computation cost."
            ),
        })
        .strict(),
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
      },
    },
    async (params) => {
      try {
        const ai = await getClient();
        const response = await ai.models.embedContent({
          model: "text-embedding-004",
          contents: params.texts,
          config: {
            taskType: params.task_type,
            outputDimensionality: params.dimensions,
          },
        });

        const embeddings = response.embeddings ?? [];
        const embeddingDimensions =
          embeddings.length > 0 && embeddings[0].values
            ? embeddings[0].values.length
            : params.dimensions ?? 768;

        const result = {
          embeddings,
          metadata: {
            texts: params.texts.length,
            dimensions: embeddingDimensions,
          },
        };

        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify(result, null, 2),
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
              text: `Error generating embeddings: ${message}`,
            },
          ],
        };
      }
    }
  );
}
