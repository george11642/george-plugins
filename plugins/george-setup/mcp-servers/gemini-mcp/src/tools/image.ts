import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { getClient } from "../lib/client.js";
import { saveImage, readFileAsBase64 } from "../lib/files.js";

const aspectRatioEnum = z
  .enum([
    "1:1",
    "2:3",
    "3:2",
    "3:4",
    "4:3",
    "4:5",
    "5:4",
    "9:16",
    "16:9",
    "21:9",
  ])
  .optional()
  .default("1:1")
  .describe(
    "Aspect ratio for the generated image. Default: '1:1'. " +
      "Common uses: '16:9' for widescreen/presentations, '9:16' for mobile/stories, " +
      "'4:3' for standard photos, '3:2' for DSLR-style, '21:9' for ultrawide/cinematic."
  );

const resolutionEnum = z
  .enum(["1K", "2K", "4K"])
  .optional()
  .default("2K")
  .describe(
    "Output image resolution. '1K' = fastest/smallest, '2K' = balanced (default), '4K' = highest quality/largest file. " +
      "Higher resolution increases generation time."
  );

interface ImageResult {
  texts: string[];
  filePaths: string[];
}

function extractImageResults(response: any): ImageResult {
  const texts: string[] = [];
  const filePaths: string[] = [];

  const parts = response.candidates?.[0]?.content?.parts;
  if (!parts || !Array.isArray(parts)) {
    return { texts: ["No content returned from Gemini."], filePaths: [] };
  }

  for (const part of parts) {
    if (part.inlineData?.data) {
      const filePath = saveImage(part.inlineData.data);
      filePaths.push(filePath);
    }
    if (part.text) {
      texts.push(part.text);
    }
  }

  return { texts, filePaths };
}

function formatResponse(result: ImageResult): {
  content: Array<{ type: "text"; text: string }>;
} {
  const lines: string[] = [];

  if (result.texts.length > 0) {
    lines.push(result.texts.join("\n"));
  }

  if (result.filePaths.length > 0) {
    lines.push(
      `Generated ${result.filePaths.length} image(s):`,
      ...result.filePaths.map((p) => `  ${p}`)
    );
  } else if (result.texts.length === 0) {
    lines.push("No images or text were returned from Gemini.");
  }

  return {
    content: [{ type: "text" as const, text: lines.join("\n") }],
  };
}

function formatError(error: unknown): {
  content: Array<{ type: "text"; text: string }>;
} {
  const message = error instanceof Error ? error.message : String(error);
  return {
    content: [
      { type: "text" as const, text: `Error generating image: ${message}` },
    ],
  };
}

export function registerImageTools(server: McpServer): void {
  // Tool 1: gemini_image (Pro - high quality, 4K support)
  server.registerTool(
    "gemini_image",
    {
      title: "Gemini Image Generation (Pro)",
      description:
        "Generate images using Gemini 3.1 Pro Image Preview (Nano Banana Pro). " +
        "Best-in-class text rendering in images, supports up to 4K resolution. " +
        "Use this for high-quality image generation where detail, text accuracy, and resolution matter. " +
        "Supports Google Search grounding to incorporate real-time information into generated images. " +
        "For faster iteration with lower quality, use gemini_image_fast instead. " +
        "To edit an existing image, use gemini_image_edit instead.",
      inputSchema: z
        .object({
          prompt: z
            .string()
            .describe(
              "Image generation prompt. Be descriptive about the desired image content, style, composition, " +
                "lighting, colors, and any text that should appear in the image. " +
                "More detailed prompts generally produce better results."
            ),
          aspect_ratio: aspectRatioEnum,
          resolution: resolutionEnum,
          use_search: z
            .boolean()
            .optional()
            .default(false)
            .describe(
              "Enable Google Search grounding. When true, Gemini can use real-time search results " +
                "to inform image generation (e.g., generating images of current events, real products, " +
                "or recent trends). Default: false."
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
        const config: any = {
          responseModalities: ["TEXT", "IMAGE"],
          imageConfig: {
            aspectRatio: params.aspect_ratio,
            imageSize: params.resolution,
          },
        };
        if (params.use_search) {
          config.tools = [{ googleSearch: {} }];
        }

        const response = await ai.models.generateContent({
          model: "gemini-3-pro-image-preview",
          contents: params.prompt,
          config,
        });

        const result = extractImageResults(response);
        return formatResponse(result);
      } catch (error) {
        return formatError(error);
      }
    }
  );

  // Tool 2: gemini_image_fast (Flash - fast iteration)
  server.registerTool(
    "gemini_image_fast",
    {
      title: "Gemini Image Generation (Flash)",
      description:
        "Generate images using Gemini 2.5 Flash Image (Nano Banana). " +
        "Optimized for fast iteration and quick previews. Significantly faster than gemini_image " +
        "but does not support resolution control (no 4K). " +
        "Use this when speed matters more than maximum quality, for rapid prototyping, " +
        "or when generating multiple variations quickly. " +
        "Supports Google Search grounding for real-time information. " +
        "For highest quality output, use gemini_image instead. " +
        "To edit an existing image, use gemini_image_edit instead.",
      inputSchema: z
        .object({
          prompt: z
            .string()
            .describe(
              "Image generation prompt. Be descriptive about the desired image content, style, composition, " +
                "lighting, colors, and any text that should appear in the image. " +
                "More detailed prompts generally produce better results."
            ),
          aspect_ratio: aspectRatioEnum,
          use_search: z
            .boolean()
            .optional()
            .default(false)
            .describe(
              "Enable Google Search grounding. When true, Gemini can use real-time search results " +
                "to inform image generation (e.g., generating images of current events, real products, " +
                "or recent trends). Default: false."
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
        const config: any = {
          responseModalities: ["TEXT", "IMAGE"],
          imageConfig: {
            aspectRatio: params.aspect_ratio,
          },
        };
        if (params.use_search) {
          config.tools = [{ googleSearch: {} }];
        }

        const response = await ai.models.generateContent({
          model: "gemini-2.5-flash-image",
          contents: params.prompt,
          config,
        });

        const result = extractImageResults(response);
        return formatResponse(result);
      } catch (error) {
        return formatError(error);
      }
    }
  );

  // Tool 3: gemini_image_edit (Pro - edit existing images)
  server.registerTool(
    "gemini_image_edit",
    {
      title: "Gemini Image Edit (Pro)",
      description:
        "Edit an existing image using Gemini 3.1 Pro Image Preview. " +
        "Provide a source image file and a natural language instruction describing the desired edit. " +
        "Supports a wide range of edits: background removal/replacement, color adjustments, " +
        "object removal/addition, style transfer, text overlay, retouching, and more. " +
        "The edited image is saved to disk and the file path is returned. " +
        "Supports up to 4K output resolution. " +
        "For generating new images from scratch, use gemini_image or gemini_image_fast instead.",
      inputSchema: z
        .object({
          image_path: z
            .string()
            .describe(
              "Absolute path to the image file to edit. Supports PNG, JPEG, GIF, and WebP formats. " +
                "Tilde (~) paths are resolved to the home directory."
            ),
          instruction: z
            .string()
            .describe(
              "Natural language instruction describing the desired edit. " +
                "Examples: 'Remove the background', 'Make the sky blue', 'Add sunglasses', " +
                "'Convert to watercolor style', 'Remove the person on the left', " +
                "'Add text saying HELLO at the top'."
            ),
          aspect_ratio: aspectRatioEnum,
          resolution: resolutionEnum,
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
        const { data, mimeType } = readFileAsBase64(params.image_path);

        const response = await ai.models.generateContent({
          model: "gemini-3-pro-image-preview",
          contents: [
            {
              role: "user",
              parts: [
                { text: params.instruction },
                { inlineData: { data, mimeType } },
              ],
            },
          ],
          config: {
            responseModalities: ["TEXT", "IMAGE"],
            imageConfig: {
              aspectRatio: params.aspect_ratio,
              imageSize: params.resolution,
            },
          },
        });

        const result = extractImageResults(response);
        return formatResponse(result);
      } catch (error) {
        return formatError(error);
      }
    }
  );
}
