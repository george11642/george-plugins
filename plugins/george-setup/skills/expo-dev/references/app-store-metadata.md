# App Store Metadata

Manage App Store metadata and optimize for ASO using EAS Metadata.

## What is EAS Metadata?

EAS Metadata automates App Store presence management from the command line using a `store.config.json` file instead of manually filling forms in App Store Connect. It includes built-in validation to catch common rejection pitfalls.

**Current Status:** Preview, Apple App Store only.

## Getting Started

### Pull Existing Metadata

If your app is already published, pull current metadata:

```bash
eas metadata:pull
```

This creates `store.config.json` with your current App Store configuration.

### Push Metadata Updates

After editing your config, push changes:

```bash
eas metadata:push
```

**Important:** You must submit a binary via `eas submit` before pushing metadata for new apps.

## Configuration File

Create `store.config.json` at your project root:

```json
{
  "configVersion": 0,
  "apple": {
    "copyright": "2025 Your Company",
    "categories": ["UTILITIES", "PRODUCTIVITY"],
    "info": {
      "en-US": {
        "title": "App Name",
        "subtitle": "Your compelling tagline",
        "description": "Full app description...",
        "keywords": ["keyword1", "keyword2", "keyword3"],
        "releaseNotes": "What's new in this version...",
        "promoText": "Limited time offer!",
        "privacyPolicyUrl": "https://example.com/privacy",
        "supportUrl": "https://example.com/support",
        "marketingUrl": "https://example.com"
      }
    },
    "advisory": {
      "alcoholTobaccoOrDrugUseOrReferences": "NONE",
      "gamblingSimulated": "NONE",
      "medicalOrTreatmentInformation": "NONE",
      "profanityOrCrudeHumor": "NONE",
      "sexualContentGraphicAndNudity": "NONE",
      "sexualContentOrNudity": "NONE",
      "horrorOrFearThemes": "NONE",
      "matureOrSuggestiveThemes": "NONE",
      "violenceCartoonOrFantasy": "NONE",
      "violenceRealistic": "NONE",
      "violenceRealisticProlongedGraphicOrSadistic": "NONE",
      "contests": "NONE",
      "gambling": false,
      "unrestrictedWebAccess": false,
      "seventeenPlus": false
    },
    "release": {
      "automaticRelease": true,
      "phasedRelease": true
    },
    "review": {
      "firstName": "John",
      "lastName": "Doe",
      "email": "review@example.com",
      "phone": "+1 555-123-4567",
      "notes": "Demo account: test@example.com / password123"
    }
  }
}
```

## App Store Optimization (ASO)

### Title Optimization (30 characters max)

The title is the most important ranking factor. Include your brand name and 1-2 strongest keywords.

```json
{
  "title": "Budgetly - Money Tracker"
}
```

**Best Practices:**

- Brand name first for recognition
- Include highest-volume keyword
- Avoid generic words like "app" or "the"
- Title keywords boost rankings by ~10%

### Subtitle Optimization (30 characters max)

The subtitle appears below your title in search results. Use it for your unique value proposition.

```json
{
  "subtitle": "Smart Expense & Budget Planner"
}
```

**Best Practices:**

- Don't duplicate keywords from title (Apple counts each word once)
- Highlight your main differentiator
- Include secondary high-value keywords
- Focus on benefits, not features

### Keywords Field (100 characters max)

Hidden from users but crucial for discoverability. Use comma-separated keywords without spaces after commas.

```json
{
  "keywords": [
    "finance,budget,expense,money,tracker,savings,bills,income,spending,wallet,personal,weekly,monthly"
  ]
}
```

**Best Practices:**

- Use all 100 characters
- Separate with commas only (no spaces)
- No duplicates from title/subtitle
- Include singular forms (Apple handles plurals)
- Add synonyms and alternate spellings
- Include competitor brand names (carefully)
- Use digits instead of spelled numbers ("5" not "five")
- Skip articles and prepositions

### Description Optimization

The iOS description is NOT indexed for search but critical for conversion. Focus on convincing users to download.

**Best Practices:**

- Front-load the first 3 lines (visible before "more")
- Use bullet points for features
- Include social proof (user counts, ratings, awards)
- Add a clear call-to-action
- Mention privacy/security for sensitive apps
- Update with each release

### Promo Text (170 characters max)

Appears above description; can be updated without new binary. Great for time-sensitive promotions.

## Categories

Primary category is most important for browsing and rankings.

```json
{
  "categories": ["FINANCE", "PRODUCTIVITY"]
}
```

**Available Categories:**

- BOOKS, BUSINESS, DEVELOPER_TOOLS, EDUCATION
- ENTERTAINMENT, FINANCE, FOOD_AND_DRINK
- GAMES (with subcategories), GRAPHICS_AND_DESIGN
- HEALTH_AND_FITNESS, KIDS (age-gated)
- LIFESTYLE, MAGAZINES_AND_NEWSPAPERS
- MEDICAL, MUSIC, NAVIGATION, NEWS
- PHOTO_AND_VIDEO, PRODUCTIVITY, REFERENCE
- SHOPPING, SOCIAL_NETWORKING, SPORTS
- STICKERS (with subcategories), TRAVEL
- UTILITIES, WEATHER

## Localization

Localize metadata for each target market. Keywords should be researched per locale--direct translations often miss regional search terms.

**Supported Locales:**
`ar-SA`, `ca`, `cs`, `da`, `de-DE`, `el`, `en-AU`, `en-CA`, `en-GB`, `en-US`, `es-ES`, `es-MX`, `fi`, `fr-CA`, `fr-FR`, `he`, `hi`, `hr`, `hu`, `id`, `it`, `ja`, `ko`, `ms`, `nl-NL`, `no`, `pl`, `pt-BR`, `pt-PT`, `ro`, `ru`, `sk`, `sv`, `th`, `tr`, `uk`, `vi`, `zh-Hans`, `zh-Hant`

## Dynamic Configuration

Use JavaScript for dynamic values like copyright year or fetched translations.

### Basic Dynamic Config

```js
// store.config.js
const baseConfig = require("./store.config.json");

const year = new Date().getFullYear();

module.exports = {
  ...baseConfig,
  apple: {
    ...baseConfig.apple,
    copyright: `${year} Your Company, Inc.`,
  },
};
```

Update `eas.json` to use JS config:

```json
{
  "cli": {
    "metadataPath": "./store.config.js"
  }
}
```

## Age Rating (Advisory)

**Content Descriptors:**

- `NONE` - Content not present
- `INFREQUENT_OR_MILD` - Occasional mild content
- `FREQUENT_OR_INTENSE` - Regular or strong content

**Kids Age Bands:** `FIVE_AND_UNDER`, `SIX_TO_EIGHT`, `NINE_TO_ELEVEN`

## Release Strategy

```json
{
  "release": {
    "automaticRelease": true,
    "phasedRelease": true
  }
}
```

**Options:**

- `automaticRelease: true` - Release immediately upon approval
- `automaticRelease: false` - Manual release after approval
- `automaticRelease: "2025-02-01T10:00:00Z"` - Schedule release (RFC 3339)
- `phasedRelease: true` - 7-day gradual rollout (1%, 2%, 5%, 10%, 20%, 50%, 100%)

## Tips

- Update metadata every 4-6 weeks for optimal ASO
- 70% of App Store visitors use search to find apps
- Apps with 4+ star ratings get featured more often
- Localized apps see 128% more downloads per country
- First 3 lines of description are most critical (shown before "more")
- Use all 100 keyword characters--every character counts
