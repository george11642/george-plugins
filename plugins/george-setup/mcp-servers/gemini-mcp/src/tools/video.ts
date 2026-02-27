import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { readFileSync } from "fs";
import { extname } from "path";
import { getClient } from "../lib/client.js";
import { saveVideo } from "../lib/files.js";

function getMimeType(filePath: string): string {
  const ext = extname(filePath).toLowerCase();
  const mimeTypes: Record<string, string> = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".webp": "image/webp",
    ".gif": "image/gif",
  };
  return mimeTypes[ext] || "image/png";
}

const operations = new Map<string, any>();
let operationCounter = 0;

function nextOperationId(): string {
  operationCounter++;
  return `video-op-${Date.now()}-${operationCounter}`;
}

export function registerVideoTools(server: McpServer): void {
  // Tool 1: gemini_video (async video generation)
  server.registerTool(
    "gemini_video",
    {
      title: "Gemini Video Generation (Veo)",
      description:
        "Generate videos using Google Veo 3.1. Video generation is asynchronous and typically " +
        "takes 1-3 minutes to complete. This tool starts the generation and returns an operation ID. " +
        "You MUST then poll for completion using gemini_video_status with the returned operation ID. " +
        "Check every 10-30 seconds until the video is ready. " +
        "The completed video will be saved as an MP4 file.",
      inputSchema: z
        .object({
          prompt: z
            .string()
            .describe(
              "Video description prompt. Be descriptive about the desired video content, motion, " +
                "camera movement, style, lighting, and mood. " +
                "More detailed prompts generally produce better results."
            ),
          image_path: z
            .string()
            .optional()
            .describe(
              "Path to an input image for image-to-video generation. " +
                "When provided, Veo will animate this image into a video clip. " +
                "Supports PNG, JPEG, WebP. The prompt should describe the desired motion/animation."
            ),
          model: z
            .enum(["veo-3.1-generate-preview", "veo-3.1-fast-generate-preview"])
            .optional()
            .default("veo-3.1-generate-preview")
            .describe(
              "Model to use for video generation. " +
                "'veo-3.1-generate-preview' = highest quality (default), " +
                "'veo-3.1-fast-generate-preview' = faster generation with lower quality."
            ),
          aspect_ratio: z
            .enum(["16:9", "9:16"])
            .optional()
            .default("16:9")
            .describe(
              "Aspect ratio for the generated video. " +
                "'16:9' for landscape/widescreen (default), '9:16' for portrait/mobile/stories."
            ),
          person_generation: z
            .enum(["allow_all", "allow_adult"])
            .optional()
            .default("allow_all")
            .describe(
              "Whether to allow generation of people in the video. " +
                "'allow_all' = allow generation of people (default for text-to-video), " +
                "'allow_adult' = only allow adult persons (required for image-to-video)."
            ),
        })
        .strict(),
      annotations: {
        readOnlyHint: false,
        destructiveHint: false,
      },
    },
    async (params) => {
      try {
        const ai = await getClient();

        // Build request parameters
        const generateParams: any = {
          model: params.model,
          prompt: params.prompt,
          config: {
            personGeneration: params.person_generation,
            aspectRatio: params.aspect_ratio,
          },
        };

        // Add image for image-to-video generation
        if (params.image_path) {
          const imageBuffer = readFileSync(params.image_path);
          const base64Data = imageBuffer.toString("base64");
          const mimeType = getMimeType(params.image_path);
          generateParams.image = {
            imageBytes: base64Data,
            mimeType,
          };
        }

        const operation = await ai.models.generateVideos(generateParams);

        const opId = nextOperationId();
        operations.set(opId, operation);

        return {
          content: [
            {
              type: "text" as const,
              text:
                `Video generation started. Operation ID: ${opId}\n\n` +
                `Use gemini_video_status with operation_id "${opId}" to check progress. ` +
                `Video generation typically takes 1-3 minutes. Poll every 10-30 seconds.`,
            },
          ],
        };
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return {
          content: [
            {
              type: "text" as const,
              text: `Error starting video generation: ${message}`,
            },
          ],
        };
      }
    }
  );

  // Tool 2: gemini_video_status (check/download completed video)
  server.registerTool(
    "gemini_video_status",
    {
      title: "Gemini Video Generation Status",
      description:
        "Check the status of an async video generation operation started by gemini_video. " +
        "If the video is complete, it will be downloaded and saved as an MP4 file. " +
        "If still generating, try again in 10-30 seconds.",
      inputSchema: z
        .object({
          operation_id: z
            .string()
            .describe(
              "The operation ID returned by gemini_video."
            ),
        })
        .strict(),
      annotations: {
        readOnlyHint: false,
        destructiveHint: false,
      },
    },
    async (params) => {
      try {
        const ai = await getClient();
        let operation = operations.get(params.operation_id);

        if (!operation) {
          return {
            content: [
              {
                type: "text" as const,
                text: `Error: Operation not found for ID "${params.operation_id}". ` +
                  `Make sure you are using the operation ID returned by gemini_video.`,
              },
            ],
          };
        }

        // Poll once to update status
        operation = await ai.operations.getVideosOperation({ operation });
        operations.set(params.operation_id, operation);

        if (!operation.done) {
          return {
            content: [
              {
                type: "text" as const,
                text: "Video is still generating. Try again in 10-30 seconds.",
              },
            ],
          };
        }

        // Download completed videos
        const savedPaths: string[] = [];
        if (operation.response?.generatedVideos) {
          for (const video of operation.response.generatedVideos) {
            const videoUrl = `${video.video.uri}&key=${process.env.GEMINI_API_KEY}`;
            const resp = await fetch(videoUrl);
            const buffer = Buffer.from(await resp.arrayBuffer());
            const filePath = saveVideo(buffer);
            savedPaths.push(filePath);
          }
        }

        // Clean up the operation from the map
        operations.delete(params.operation_id);

        if (savedPaths.length === 0) {
          return {
            content: [
              {
                type: "text" as const,
                text: "Video generation completed but no videos were returned.",
              },
            ],
          };
        }

        return {
          content: [
            {
              type: "text" as const,
              text:
                `Video generation complete. Saved ${savedPaths.length} video(s):\n` +
                savedPaths.map((p) => `  ${p}`).join("\n"),
            },
          ],
        };
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return {
          content: [
            {
              type: "text" as const,
              text: `Error checking video status: ${message}`,
            },
          ],
        };
      }
    }
  );
}
