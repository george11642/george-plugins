import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { getClient } from "../lib/client.js";

export function registerCodeTools(server: McpServer): void {
  server.registerTool(
    "gemini_code_execute",
    {
      title: "Gemini Code Execution",
      description:
        "Run Python code via Gemini's built-in code execution tool. " +
        "Provide a natural language description of what you want to compute, or a direct Python code snippet. " +
        "Gemini will write Python code, execute it in Google's sandboxed environment, and return the results. " +
        "Supports Python only. Ideal for math calculations, data analysis, string manipulation, " +
        "algorithm prototyping, statistical computations, and any task that benefits from actual code execution. " +
        "The sandbox has no network access and no filesystem persistence between calls.",
      inputSchema: z
        .object({
          prompt: z
            .string()
            .describe(
              "Description of what code to write and execute, or a direct code snippet. " +
                "Gemini will write Python code, execute it in a sandboxed environment, and return the results."
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
          model: "gemini-3.1-pro-preview",
          contents: params.prompt,
          config: {
            tools: [{ codeExecution: {} }],
          },
        });

        const parts = response.candidates?.[0]?.content?.parts;
        if (!parts || parts.length === 0) {
          return {
            content: [
              {
                type: "text" as const,
                text: "(empty response - no parts returned)",
              },
            ],
          };
        }

        const sections: string[] = [];

        for (const part of parts) {
          if (part.text) {
            sections.push(part.text);
          }

          if (part.executableCode) {
            sections.push(
              `\`\`\`${part.executableCode.language ?? "python"}\n${part.executableCode.code}\n\`\`\``
            );
          }

          if (part.codeExecutionResult) {
            const outcome = part.codeExecutionResult.outcome ?? "UNKNOWN";
            const output = part.codeExecutionResult.output ?? "(no output)";
            sections.push(
              `**Execution Result** (${outcome}):\n\`\`\`\n${output}\n\`\`\``
            );
          }
        }

        return {
          content: [
            {
              type: "text" as const,
              text: sections.join("\n\n"),
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
              text: `Error executing code via Gemini: ${message}`,
            },
          ],
        };
      }
    }
  );
}
