# Design System: Colors, Typography, Spacing, Brand

## Color Palettes by Product Type

### SaaS / Tech
| Name | Primary | Secondary | Accent | Background | Text |
|------|---------|-----------|--------|------------|------|
| Classic Blue | #1C2833 | #2E4053 | #3498DB | #F4F6F6 | #2C3E50 |
| Teal & Coral | #277884 | #5EA8A7 | #FE4447 | #FFFFFF | #1A1A1A |
| Deep Purple | #B165FB | #181B24 | #40695B | #FFFFFF | #181B24 |
| Tech Innovation | #0A84FF | #1E1E1E | #30D158 | #000000 | #F5F5F7 |

### E-commerce / Retail
| Name | Primary | Secondary | Accent | Background | Text |
|------|---------|-----------|--------|------------|------|
| Vibrant Orange | #F96D00 | #222831 | #F2F2F2 | #FFFFFF | #222831 |
| Black & Gold | #BF9A4A | #000000 | #F4F6F6 | #FFFFFF | #1A1A1A |
| Bold Red | #C0392B | #E74C3C | #F39C12 | #FFFFFF | #2C3E50 |

### Healthcare / Wellness
| Name | Primary | Secondary | Accent | Background | Text |
|------|---------|-----------|--------|------------|------|
| Warm Blush | #A49393 | #EED6D3 | #E8B4B8 | #FAF7F2 | #3D3D3D |
| Sage & Terra | #87A96B | #E07A5F | #F4F1DE | #FFFFFF | #2C2C2C |
| Coastal Rose | #AD7670 | #B49886 | #BFD5BE | #F3ECDC | #2C2C2C |

### Fintech / Corporate
| Name | Primary | Secondary | Accent | Background | Text |
|------|---------|-----------|--------|------------|------|
| Burgundy | #5D1D2E | #951233 | #997929 | #FAF9F7 | #1A1A1A |
| Forest Green | #1E5128 | #4E9F3D | #FFFFFF | #191A19 | #FFFFFF |
| Charcoal & Red | #292929 | #CCCBCB | #E33737 | #FFFFFF | #292929 |

### Brand: Anthropic
| Element | Color |
|---------|-------|
| Dark | #141413 |
| Light | #faf9f5 |
| Mid Gray | #b0aea5 |
| Light Gray | #e8e6dc |
| Orange accent | #d97757 |
| Blue accent | #6a9bcc |
| Green accent | #788c5d |
| Heading font | Poppins |
| Body font | Lora |

## Typography

### Font Pairing Categories

**Modern / Clean**
- Inter + Source Serif Pro
- DM Sans + DM Serif Display
- Geist + Geist Mono

**Elegant / Luxury**
- Playfair Display + Lato
- Cormorant Garamond + Proza Libre
- Bodoni Moda + Nunito Sans

**Playful / Creative**
- Poppins + Nunito
- Quicksand + Open Sans
- Space Grotesk + Space Mono

**Professional / Corporate**
- Montserrat + Merriweather
- Raleway + Roboto
- Work Sans + Source Serif Pro

**Technical / Developer**
- JetBrains Mono + Inter
- Fira Code + Fira Sans
- IBM Plex Mono + IBM Plex Sans

### Typography Scale
| Level | Size | Weight | Line Height | Use |
|-------|------|--------|-------------|-----|
| Display | 48-72px | 700-800 | 1.1-1.2 | Hero headlines |
| H1 | 36-48px | 700 | 1.2-1.3 | Page titles |
| H2 | 28-36px | 600-700 | 1.3 | Section titles |
| H3 | 22-28px | 600 | 1.3-1.4 | Subsections |
| H4 | 18-22px | 500-600 | 1.4 | Card titles |
| Body | 16-18px | 400 | 1.5-1.75 | Paragraphs |
| Small | 14px | 400 | 1.5 | Captions, meta |
| Tiny | 12px | 400-500 | 1.4 | Labels, badges |

### Typography Rules
- Line height: 1.5-1.75 for body text
- Line length: 65-75 characters per line
- Match heading/body font personalities (don't pair two display fonts)
- Web-safe fallbacks: `font-family: 'Poppins', Arial, sans-serif`

## Spacing System (8px grid)

| Token | Value | Use |
|-------|-------|-----|
| xs | 4px | Icon gaps, tight padding |
| sm | 8px | Inline spacing, small gaps |
| md | 16px | Component padding, list gaps |
| lg | 24px | Section spacing |
| xl | 32px | Card padding |
| 2xl | 48px | Section margins |
| 3xl | 64px | Page sections |
| 4xl | 96px | Hero spacing |

## Shadow System
| Level | Value | Use |
|-------|-------|-----|
| sm | `0 1px 2px rgba(0,0,0,0.05)` | Subtle cards |
| md | `0 4px 6px rgba(0,0,0,0.07)` | Elevated cards |
| lg | `0 10px 15px rgba(0,0,0,0.1)` | Dropdowns |
| xl | `0 20px 25px rgba(0,0,0,0.15)` | Modals |

## Border Radius Scale
| Token | Value | Use |
|-------|-------|-----|
| sm | 4px | Inputs, small elements |
| md | 8px | Cards, buttons |
| lg | 12px | Larger cards |
| xl | 16px | Feature cards |
| full | 9999px | Pills, avatars |
