# Remotion — Video in React

Consolidated from: remotion-best-practices

## Core Concepts

Remotion renders React components as video frames. Each frame is a React render at a specific time.

### Composition Definition
```tsx
import { Composition } from "remotion"

export const RemotionRoot = () => (
  <Composition
    id="MyVideo"
    component={MyVideo}
    durationInFrames={300}  // 10 seconds at 30fps
    fps={30}
    width={1080}
    height={1920}  // 9:16 portrait
    defaultProps={{ title: "Hello" }}
    schema={mySchema}  // Zod schema for type-safe props
  />
)
```

### Animation with Interpolation
```tsx
import { useCurrentFrame, interpolate, spring } from "remotion"

const MyComponent = () => {
  const frame = useCurrentFrame()
  
  // Linear interpolation
  const opacity = interpolate(frame, [0, 30], [0, 1], {
    extrapolateRight: "clamp"
  })
  
  // Spring animation
  const scale = spring({ frame, fps: 30, config: { damping: 12 } })
  
  return <div style={{ opacity, transform: `scale(${scale})` }}>Hello</div>
}
```

### Sequencing
```tsx
import { Sequence } from "remotion"

const Video = () => (
  <>
    <Sequence from={0} durationInFrames={90}>
      <Intro />
    </Sequence>
    <Sequence from={90} durationInFrames={120}>
      <MainContent />
    </Sequence>
    <Sequence from={210}>
      <Outro />
    </Sequence>
  </>
)
```

## Key Features

### Captions (TikTok-style)
```tsx
import { Caption } from "@remotion/captions"

// Import SRT file
import { parseSrt } from "@remotion/captions"
const captions = parseSrt(srtContent)

// Display with word highlighting
<Caption
  captions={captions}
  startFrom={0}
  style={{ fontSize: 48, fontWeight: "bold" }}
/>
```

### Video Embedding
```tsx
import { OffthreadVideo, Video } from "remotion"

// OffthreadVideo for better performance (renders frames, not real-time)
<OffthreadVideo src={videoUrl} startFrom={30} endAt={300} volume={0.8} />
```

### Audio
```tsx
import { Audio } from "remotion"

<Audio src={audioUrl} startFrom={0} volume={(f) => interpolate(f, [0, 30], [0, 1])} />
```

### Dynamic Metadata
```tsx
export const calculateMetadata = async ({ props }) => {
  const duration = await getVideoDuration(props.videoUrl)
  return {
    durationInFrames: Math.ceil(duration * 30),
    props: { ...props, duration }
  }
}
```

## Media Utilities (Mediabunny)
- `getVideoDuration(src)` — duration in seconds
- `getVideoMetadata(src)` — width, height, duration, codec
- `canDecode(src)` — browser compatibility check
- `extractFrame(src, time)` — extract frame as image

## Transitions
```tsx
import { TransitionSeries, slide, fade, wipe } from "@remotion/transitions"

<TransitionSeries>
  <TransitionSeries.Sequence durationInFrames={90}>
    <SceneA />
  </TransitionSeries.Sequence>
  <TransitionSeries.Transition
    presentation={slide({ direction: "from-left" })}
    timing={springTiming({ config: { damping: 200 } })}
  />
  <TransitionSeries.Sequence durationInFrames={90}>
    <SceneB />
  </TransitionSeries.Sequence>
</TransitionSeries>
```

## Tailwind in Remotion
```tsx
// remotion.config.ts
Config.overrideWebpackConfig((config) => {
  // Add Tailwind PostCSS processing
  return enableTailwind(config)
})
```

## Best Practices
- Use `OffthreadVideo` over `Video` for server-side rendering
- Pre-calculate metadata with `calculateMetadata`
- Use `spring()` for natural motion, `interpolate()` for linear
- Zod schemas for type-safe, parametrizable compositions
- `delayRender()`/`continueRender()` for async data loading
