# expo/fetch and Streaming

`expo/fetch` is a WinterCG-compliant Fetch API available in SDK 52+. It supports streaming responses (`ReadableStream`) on all platforms — iOS, Android, and Web — which the global React Native `fetch` does not.

## Why expo/fetch vs Global fetch

| Feature | `expo/fetch` | Global `fetch` (RN) |
|---------|-------------|---------------------|
| Streaming (ReadableStream) | Yes | No (RN limitation) |
| Consistent cross-platform | Yes | Inconsistent |
| WinterCG compliant | Yes | Partial |
| SSE / AI streaming APIs | Yes | No |
| Abort / cancellation | Yes | Yes |

The global `fetch` in React Native does not expose `response.body` as a streamable `ReadableStream`. `expo/fetch` adds a full WinterCG-compliant implementation so streaming works the same as in modern browsers.

---

## Installation and Import

Available automatically in Expo SDK 52+. No installation needed beyond having `expo` in your project.

```typescript
// Explicit import (preferred for clarity)
import { fetch } from 'expo/fetch';

// Or use the global (expo/fetch polyfills global fetch in SDK 52+)
// fetch(...) works too, but explicit import is more reliable
```

---

## Basic Streaming Response

```typescript
import { fetch } from 'expo/fetch';

async function streamResponse(url: string) {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ prompt: 'Hello' }),
  });

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }

  const reader = response.body!.getReader();
  const decoder = new TextDecoder();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    const chunk = decoder.decode(value, { stream: true });
    console.log('chunk:', chunk);
  }
}
```

---

## SSE (Server-Sent Events) Parsing

AI APIs like OpenAI and Anthropic use SSE format for streaming. Each chunk is prefixed with `data: `.

```typescript
import { fetch } from 'expo/fetch';

async function streamSSE(url: string, apiKey: string, prompt: string) {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o',
      messages: [{ role: 'user', content: prompt }],
      stream: true,
    }),
  });

  const reader = response.body!.getReader();
  const decoder = new TextDecoder();
  let buffer = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop() ?? '';  // keep incomplete line in buffer

    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const data = line.slice(6).trim();
        if (data === '[DONE]') return;

        try {
          const json = JSON.parse(data);
          const content = json.choices?.[0]?.delta?.content;
          if (content) yield content;
        } catch {
          // Skip malformed chunks
        }
      }
    }
  }
}
```

---

## Claude / Anthropic Streaming

```typescript
import { fetch } from 'expo/fetch';

async function* streamClaude(prompt: string, apiKey: string) {
  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: 'claude-opus-4-5',
      max_tokens: 1024,
      stream: true,
      messages: [{ role: 'user', content: prompt }],
    }),
  });

  const reader = response.body!.getReader();
  const decoder = new TextDecoder();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    const text = decoder.decode(value, { stream: true });
    const lines = text.split('\n').filter(l => l.startsWith('data: '));

    for (const line of lines) {
      const data = line.slice(6);
      if (data === '[DONE]') return;
      try {
        const event = JSON.parse(data);
        if (event.type === 'content_block_delta') {
          yield event.delta.text ?? '';
        }
      } catch {}
    }
  }
}
```

---

## React State Update Pattern (Chat UI)

```tsx
import { fetch } from 'expo/fetch';
import { useState, useRef } from 'react';

function ChatScreen() {
  const [messages, setMessages] = useState<string[]>([]);
  const [currentMessage, setCurrentMessage] = useState('');
  const [isStreaming, setIsStreaming] = useState(false);
  const abortRef = useRef<AbortController | null>(null);

  async function sendMessage(prompt: string) {
    setIsStreaming(true);
    setCurrentMessage('');

    abortRef.current = new AbortController();

    try {
      const response = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt }),
        signal: abortRef.current.signal,
      });

      const reader = response.body!.getReader();
      const decoder = new TextDecoder();
      let accumulated = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        accumulated += decoder.decode(value, { stream: true });
        setCurrentMessage(accumulated);  // React batches these efficiently
      }

      setMessages(prev => [...prev, accumulated]);
      setCurrentMessage('');
    } catch (err: any) {
      if (err.name !== 'AbortError') {
        console.error('Stream error:', err);
      }
    } finally {
      setIsStreaming(false);
    }
  }

  function cancelStream() {
    abortRef.current?.abort();
  }

  return (
    // ... render messages and currentMessage
  );
}
```

---

## Abort / Cancellation

`expo/fetch` supports `AbortController` natively:

```typescript
const controller = new AbortController();

const response = await fetch(url, {
  signal: controller.signal,
});

// Cancel mid-stream
controller.abort();
```

Always abort on component unmount to prevent state updates on unmounted components:

```tsx
useEffect(() => {
  const controller = new AbortController();

  fetchStream(url, controller.signal);

  return () => controller.abort();
}, [url]);
```

---

## TextDecoderStream / TextEncoderStream

Available on all platforms in Expo SDK 52+:

```typescript
// Pipe through decoder stream (alternative to manual decode)
const textStream = response.body!
  .pipeThrough(new TextDecoderStream());

const reader = textStream.getReader();
while (true) {
  const { done, value } = await reader.read();  // value is already a string
  if (done) break;
  processLine(value);
}
```

---

## Platform Considerations

- **Android**: requires `INTERNET` permission in `AndroidManifest.xml` — already included in all Expo templates
- **iOS**: no ATS (App Transport Security) issues for HTTPS endpoints; HTTP requires `NSAllowsArbitraryLoads` exception
- **Web**: uses native browser `fetch` with streaming, fully supported
- **Expo Go**: works in Expo Go (SDK 52+) without a custom dev client

---

## Vercel AI SDK Integration

If using the Vercel AI SDK with Expo, it uses `expo/fetch` under the hood from SDK 52:

```bash
npx expo install ai
```

```typescript
import { generateText, streamText } from 'ai';
import { createOpenAI } from '@ai-sdk/openai';

const openai = createOpenAI({ apiKey });

// Streaming with Vercel AI SDK (uses expo/fetch internally)
const { textStream } = await streamText({
  model: openai('gpt-4o'),
  prompt: 'Hello',
});

for await (const delta of textStream) {
  setCurrentText(prev => prev + delta);
}
```
