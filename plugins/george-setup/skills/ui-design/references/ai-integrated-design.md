# AI-Integrated Design

Design patterns and principles for building AI-powered interfaces — covering AI-assisted generation workflows, conversational UIs, adaptive interfaces, bias mitigation, and the tooling ecosystem.

---

## AI-Assisted UI Generation

### The Current Toolchain (2025)

The AI-assisted design workflow has matured into a layered toolchain:

**Design generation**:
- **Figma AI**: In-editor component and layout generation from text prompts; directly editable in Figma
- **Stitch** (Anthropic MCP): Generates React UI components from natural language — accessible via `ToolSearch("stitch")`
- **Cursor / Claude Code**: Generates code from designs, mockups, or screenshots; best for existing codebases
- **v0 (Vercel)**: Prompt → React+Tailwind component code; excellent for rapid prototyping

**Image and asset generation**:
- **Gemini Image** MCP (`gemini_image`): Generate hero images, illustrations, icons from prompts
- **Gemini Image Edit** (`gemini_image_edit`): Modify existing images, change backgrounds, style transfer
- Adobe Firefly: Brand-safe image generation integrated into Creative Cloud

**Design-to-code translation**:
- Figma Dev Mode + AI: Extracts tokens, spacing, components with context
- Locofy, Builder.io: Figma design → React/Next.js code pipelines

### Reviewing and Adapting AI-Generated Designs

AI-generated designs require systematic review before use:

**Quality checklist**:
- [ ] Color contrast meets WCAG AA (4.5:1 for body text)
- [ ] Spacing follows the 4px grid (not arbitrary pixel values)
- [ ] Typography uses the project's defined type scale
- [ ] Touch targets are 44px minimum
- [ ] No placeholder content (Lorem ipsum, broken images)
- [ ] Interactive states exist (hover, focus, active, disabled)
- [ ] Mobile and desktop variants are consistent
- [ ] Component naming matches the design system

**Common AI slop patterns to fix**:
- Gradient overuse (purple-to-blue gradients on everything)
- All text centered, even body paragraphs
- Decorative icons with no accessible labels
- Shadow and blur effects applied inconsistently
- Hard-coded pixel values instead of token references
- Generic stock imagery that doesn't match brand

### Prompt Patterns for UI Component Generation

**Structure**: `[Component type] + [Context/purpose] + [Visual style] + [Constraints]`

```
"A pricing card component for a B2B SaaS product. Three tiers: Starter,
Pro, Enterprise. Clean minimal style, neutral colors with one highlighted
'Most Popular' tier. React with Tailwind. No gradients. Must include
annual/monthly toggle."

"A data table component showing user activity logs. Columns: user, action,
timestamp, status (badge). Dark mode. Sortable headers. Row hover state.
Pagination. shadcn/ui Table primitives."

"A loading skeleton for a card grid — 3 columns, 4 rows of cards. Each
card has a 16:9 image placeholder, two lines of text, and a button.
Animated shimmer effect. Respect prefers-reduced-motion."
```

**Iteration prompts**:
```
"Make it more compact — reduce the padding by 25% and use a smaller type scale"
"Add a destructive action button with proper confirmation pattern"
"Adapt this for mobile — single column, larger touch targets"
"Replace the color-only status indicators with icon + color + label"
```

---

## Conversational UI Patterns

### Chat Interface Components

**Message bubble anatomy**:
```
User message:   right-aligned, brand color bg, white text, rounded-tl
AI message:     left-aligned, surface bg, primary text, avatar, rounded-tr
System message: center-aligned, muted text, no bubble (e.g., "Today")
Error message:  left-aligned, error color, retry action
```

**Essential chat components**:

1. **Message list**: Virtualized scroll (react-window for long histories), auto-scroll to bottom on new message, scroll-to-bottom button when user has scrolled up

2. **Typing indicator**: Three animated dots — CSS-only preferred:
```css
.typing-dot {
  animation: bounce 1.4s infinite ease-in-out;
}
.typing-dot:nth-child(1) { animation-delay: 0s; }
.typing-dot:nth-child(2) { animation-delay: 0.2s; }
.typing-dot:nth-child(3) { animation-delay: 0.4s; }

@keyframes bounce {
  0%, 60%, 100% { transform: translateY(0); }
  30%           { transform: translateY(-6px); }
}

@media (prefers-reduced-motion: reduce) {
  .typing-dot { animation: none; opacity: 0.6; }
}
```

3. **Timestamp display**: Show relative time (2 min ago) in message; expand to absolute on hover. Group consecutive messages — show timestamp only at group boundaries.

4. **Message actions**: Hover reveals copy, regenerate, like/dislike (thumbs feedback), share — in a floating action bar, not permanently visible.

5. **Input area**: Auto-resizing textarea (max 6 lines before scroll), send on Enter (with Shift+Enter for newline), character/token counter optional, file attach, voice input when relevant.

### LLM-Powered Interface Patterns

**Streaming text display**:
```javascript
// Streaming text with cursor
const StreamingMessage = ({ content, isStreaming }) => (
  <div className="prose max-w-none">
    <ReactMarkdown>{content}</ReactMarkdown>
    {isStreaming && (
      <span
        className="inline-block w-2 h-4 bg-current ml-0.5 animate-pulse"
        aria-hidden="true"
      />
    )}
  </div>
);
```

Key streaming UX rules:
- Show partial content as it arrives — never wait for completion
- Use a blinking cursor to indicate active streaming
- Render Markdown incrementally (parse on each chunk if performance allows)
- Disable send/regenerate while streaming
- Show a "Stop generating" button during streaming

**Loading states hierarchy**:
```
1. Optimistic: Show assumed result immediately (message send)
2. Skeleton: Show structure without content (initial page load)
3. Spinner: Indeterminate wait < 10s (API call without streaming)
4. Progress: Determinate wait with known steps (file processing)
5. Typing indicator: AI is "thinking" before streaming starts
```

**Error recovery patterns**:
- Network error: "Message failed to send" + retry button — preserve the user's message
- Rate limit: "Too many requests — try again in 30 seconds" with countdown
- Content policy: Explain what happened without being preachy — offer reframing
- Context limit: "This conversation is getting long — start a new chat or summarize?" with action buttons
- Server error: "Something went wrong" + retry + report option

### Chatbot Personality and Tone in Design

Personality manifests in micro-copy, not just conversation:
- **Placeholder text**: "Ask me anything..." vs "How can I help today?" — the latter implies a service relationship
- **Empty state**: First message, no history — use this to set expectations and suggest first actions
- **Error tone**: Friendly + specific beats formal + vague. "I didn't catch that — could you rephrase?" vs "Invalid input"
- **Loading copy**: "Thinking..." vs "Analyzing your question..." vs "Working on it" — match the product's voice
- **Success states**: Celebrate appropriately without being sycophantic ("Here's what I found:" not "Great question!")

**Brand personality matrix**:
| Personality | Placeholder | Error | Loading |
|---|---|---|---|
| Professional | "How can I assist you?" | "I wasn't able to process that request." | "Processing..." |
| Friendly | "What's on your mind?" | "Oops — let's try that again!" | "Thinking..." |
| Expert | "What would you like to explore?" | "I need more context to help here." | "Analyzing..." |
| Casual | "Ask me anything" | "Something went wrong — want to retry?" | "On it..." |

### Voice + Visual Integration

When combining voice input with visual display:
- Visual waveform animation during recording (respect `prefers-reduced-motion`)
- Transcript appears as user speaks (interim results in muted text, final in normal)
- Voice playback for AI responses: speed control (0.8x-1.5x), pause, skip
- Visual fallback: all voice content must be readable as text
- Microphone permission: request on first use, explain why, provide text alternative

---

## Adaptive and Personalized Interfaces

### Context-Aware Component States

Components that adapt to user context:
```javascript
// Dashboard that adapts to user role and activity
const Dashboard = ({ user }) => {
  const isFirstVisit = user.sessionCount === 1;
  const isAdmin = user.role === 'admin';
  const hasActivity = user.recentActivity.length > 0;

  return (
    <main>
      {isFirstVisit && <OnboardingBanner />}
      {isAdmin && <AdminQuickActions />}
      {hasActivity ? <ActivityFeed items={user.recentActivity} /> : <EmptyState />}
    </main>
  );
};
```

**Context dimensions to design for**:
- **Experience level**: New user → guided, tooltips; power user → dense, keyboard shortcuts
- **Device context**: Mobile → thumb-friendly layout; desktop → expanded view
- **Time context**: Morning → daily summary; working hours → tasks; evening → reports
- **Task context**: Mid-flow → minimize chrome; idle → surface suggestions

### Personalization Without Creepy Patterns

The "creepy line" in personalization is crossed when:
- The system reveals it knows things the user didn't consciously provide
- Recommendations feel like surveillance ("We noticed you were looking at competitors")
- Personalization changes behavior users expect to be consistent (navigation moves)
- Data feels cross-context (browsing history influencing unrelated features)

**Ethical personalization design**:
- **Transparency**: Surface why something was recommended ("Because you use feature X")
- **Control**: Let users see and clear their personalization data
- **Opt-in for sensitive**: Behavioral tracking should be opt-in with clear explanation
- **Graceful degradation**: Personalization enhances; removing it shouldn't break the product
- **No dark surprises**: Changes based on AI should be visible, not silent

### AI Disclosure Patterns

When content is AI-generated, users deserve to know. 2025 regulatory trend: EU AI Act requires disclosure in many contexts.

**Disclosure approaches by context**:

| Context | Disclosure Pattern |
|---|---|
| AI-drafted email | "AI draft — review before sending" banner |
| AI-generated image | "Generated by AI" caption/badge |
| AI-written summary | "AI summary — may contain errors" with source link |
| AI-suggested content | "Suggested for you" or "AI recommendation" label |
| AI chat response | Model name/version in footer of message |
| AI-assisted form fill | "Pre-filled by AI — confirm accuracy" |

**Visual treatment for AI disclosure**:
- Subtle but visible: small badge, muted color, not alarming but not hidden
- Consistent iconography: sparkle icon (✦) has become a convention for AI features
- Actionable: disclosure should link to "What is this?" or settings for AI features

---

## AI Bias Mitigation in Design

### Avoiding Demographic Stereotypes in Imagery and Icons

AI-generated imagery has documented biases that designers must actively counter:

**Representation checklist for imagery**:
- [ ] Gender diversity across professional roles (not: male engineer, female nurse)
- [ ] Racial/ethnic diversity in hero images, testimonials, team pages
- [ ] Age diversity — include older users/employees, not only young
- [ ] Body diversity — avoid uniformly thin/able-bodied default representations
- [ ] Cultural diversity in celebrations, food, family structures shown
- [ ] Disability representation — show people with disabilities actively, not passively
- [ ] Geographic diversity — avoid US/European default settings and aesthetics

**Icon bias audit**:
- "Person" icons: Use gender-neutral designs (avoid gendered silhouettes)
- Role icons: "Doctor" should not default to male, "nurse" should not default to female
- Family icons: Include single-parent, same-sex, multigenerational representations
- Flag icons: Never use flags as language selectors (language ≠ nationality)

### Inclusive Representation Checklist

Before publishing any product imagery:
- [ ] At least 40% of visible people are non-white in aggregate across the product
- [ ] No racial homogeneity in any section (e.g., all-white testimonials)
- [ ] Professional contexts show diverse leadership, not just diverse support roles
- [ ] Alternative text is descriptive but avoids specifying race/gender unless contextually required
- [ ] Illustrations use a diverse base set — avoid "default to white skin tone + brown hair"
- [ ] Social proof (testimonials, case studies): geographic and cultural diversity

### Testing Designs with Diverse Users

Bias often isn't visible until you show the design to diverse groups:

**Structured diversity review**:
1. Review imagery with someone from each represented group
2. Run usability tests with non-majority users (different ages, abilities, backgrounds)
3. Test assistive technology compatibility (screen readers don't "see" images — alt text quality matters)
4. Review copy for cultural assumptions ("Click here to get started" assumes US business norms)

**Tools**:
- Polypane: Test with different vision simulations (protanopia, deuteranopia, achromatopsia)
- Stark (Figma plugin): Accessibility and color blind simulation directly in designs
- UserTesting: Recruit diverse participant panels

---

## Anti-Patterns in AI Interfaces

### Over-Personalization
- **Problem**: Showing different navigation, layouts, or features to different users makes support and onboarding impossible. Users share screens — when their interface looks different from a colleague's, it erodes trust.
- **Fix**: Personalize content and suggestions, not the core UI structure

### Manipulative AI Recommendations
- **Problem**: Using AI to surface "recommended for you" items that serve the business (high-margin, expiring inventory) while appearing to serve the user
- **Signs**: Recommendations that always lead to upsell, "users like you" framing for items the user would never choose
- **Fix**: Make recommendation signals transparent, offer controls, separate editorial picks from AI picks

### AI Confidence Theater
- **Problem**: Displaying AI output without confidence indicators, making all outputs appear equally reliable regardless of the model's actual certainty
- **Patterns**: Charts generated from AI estimates without error bars, summaries that fabricate citations, "100% match" scores from probabilistic systems
- **Fix**: Show uncertainty. Use ranges, confidence intervals, "approximately", "based on limited data" — users respect honesty

### Dark Patterns Enabled by AI Personalization
AI dramatically amplifies the effectiveness of dark patterns — avoid:
- **Personalized urgency**: Showing "3 people viewing this" specifically to a user based on their browsing behavior
- **Personalized pricing manipulation**: Charging more based on inferred ability to pay or desperation
- **Addiction mechanics**: AI-tuned content feeds that maximize time-on-site at the cost of user wellbeing
- **Consent fatigue exploitation**: Using AI to identify when users are most likely to click "Accept All"

### The "Magic" Problem
Interfaces that feel magical when they work feel untrustworthy when they don't. Avoid:
- AI features with no clear trigger or explanation ("How did it know that?")
- Silent AI modifications to user content without disclosure
- Automatic actions taken by AI without confirmable audit trail
- Unsolicited AI suggestions that interrupt user flow without easy dismissal
