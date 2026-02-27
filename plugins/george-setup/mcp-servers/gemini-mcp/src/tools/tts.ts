import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { getClient } from "../lib/client.js";
import { saveAudio } from "../lib/files.js";

const VOICES = [
  "Zephyr",
  "Puck",
  "Charon",
  "Kore",
  "Fenrir",
  "Leda",
  "Enceladus",
  "Algieba",
  "Autonoe",
  "Callirrhoe",
  "Despina",
  "Erinome",
  "Gacrux",
  "Hydra",
  "Isonoe",
  "Juliet",
  "Keid",
  "Laomedeia",
  "Mintaka",
  "Nashira",
  "Oberon",
  "Proteus",
  "Rasalgethi",
  "Sadachbia",
  "Trinh",
  "Umbriel",
  "Vindemiatrix",
  "Wasat",
  "Xihe",
  "Yildun",
] as const;

export function registerTtsTools(server: McpServer): void {
  server.registerTool(
    "gemini_tts",
    {
      title: "Gemini Text-to-Speech",
      description:
        "Convert text to natural-sounding speech using Gemini TTS models. " +
        "Outputs a WAV file (16-bit PCM, 24kHz, mono). " +
        "Supports 30 distinct voices with different vocal characteristics:\n\n" +
        "Voices:\n" +
        "  Zephyr - Bright, youthful tone\n" +
        "  Puck - Playful, energetic delivery\n" +
        "  Charon - Deep, authoritative voice\n" +
        "  Kore - Warm, clear female voice (default)\n" +
        "  Fenrir - Strong, commanding presence\n" +
        "  Leda - Gentle, soothing tone\n" +
        "  Enceladus - Rich, resonant baritone\n" +
        "  Algieba - Calm, measured delivery\n" +
        "  Autonoe - Smooth, professional tone\n" +
        "  Callirrhoe - Soft, melodic voice\n" +
        "  Despina - Crisp, articulate speech\n" +
        "  Erinome - Warm, conversational style\n" +
        "  Gacrux - Steady, neutral narration\n" +
        "  Hydra - Versatile, expressive range\n" +
        "  Isonoe - Light, friendly delivery\n" +
        "  Juliet - Elegant, refined tone\n" +
        "  Keid - Direct, confident voice\n" +
        "  Laomedeia - Graceful, flowing speech\n" +
        "  Mintaka - Clear, bright articulation\n" +
        "  Nashira - Relaxed, easygoing tone\n" +
        "  Oberon - Distinguished, mature voice\n" +
        "  Proteus - Adaptable, dynamic delivery\n" +
        "  Rasalgethi - Deep, thoughtful cadence\n" +
        "  Sadachbia - Cheerful, upbeat energy\n" +
        "  Trinh - Precise, polished speech\n" +
        "  Umbriel - Quiet, introspective tone\n" +
        "  Vindemiatrix - Bold, dramatic presence\n" +
        "  Wasat - Balanced, centered delivery\n" +
        "  Xihe - Serene, composed voice\n" +
        "  Yildun - Steady, reliable narration\n\n" +
        "Style and tone can be controlled through the text prompt itself. " +
        "Prefix your text with style hints to influence delivery, e.g.:\n" +
        "  'Say excitedly: Welcome to the show!'\n" +
        "  'In a whisper: The secret is...'\n" +
        "  'Read slowly and dramatically: The final countdown begins.'\n" +
        "  'Say cheerfully: Good morning everyone!'",
      inputSchema: z
        .object({
          text: z
            .string()
            .describe(
              "Text to convert to speech. Can include style hints to control delivery, " +
                "e.g. 'Say cheerfully: Hello!' or 'In a serious tone: This is important.' " +
                "The model interprets natural language instructions about how to speak the text."
            ),
          voice: z
            .enum(VOICES)
            .optional()
            .default("Kore")
            .describe(
              "Voice to use for speech synthesis. 30 voices available with distinct characteristics. " +
                "Default: 'Kore'. See tool description for full voice list with descriptions."
            ),
          model: z
            .enum([
              "gemini-2.5-flash-preview-tts",
              "gemini-2.5-pro-preview-tts",
            ])
            .optional()
            .default("gemini-2.5-flash-preview-tts")
            .describe(
              "TTS model to use. " +
                "'gemini-2.5-flash-preview-tts' = fast, cost-effective (default). " +
                "'gemini-2.5-pro-preview-tts' = higher quality, more natural prosody."
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
        const response = await ai.models.generateContent({
          model: params.model,
          contents: [{ parts: [{ text: params.text }] }],
          config: {
            responseModalities: ["AUDIO"],
            speechConfig: {
              voiceConfig: {
                prebuiltVoiceConfig: { voiceName: params.voice },
              },
            },
          },
        });

        const audioData =
          response.candidates?.[0]?.content?.parts?.[0]?.inlineData?.data;
        if (!audioData) {
          throw new Error("No audio data in response");
        }

        const audioBuffer = Buffer.from(audioData, "base64");
        const filePath = saveAudio(
          audioBuffer,
          `tts-${params.voice.toLowerCase()}`
        );

        const fileSizeKB = (audioBuffer.length / 1024).toFixed(1);

        return {
          content: [
            {
              type: "text" as const,
              text:
                `Audio generated successfully.\n` +
                `  File: ${filePath}\n` +
                `  Voice: ${params.voice}\n` +
                `  Size: ${fileSizeKB} KB`,
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
              text: `Error generating speech: ${message}`,
            },
          ],
        };
      }
    }
  );
}
