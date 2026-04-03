# CheKar Flutter App — Beta v1

**Date:** 2026-04-03
**Status:** Draft
**Depends on:** FastAPI Backend (implemented), YOLO fine-tuning (in progress)

## Purpose

Build the mobile app that Egyptian car buyers use to inspect used cars. Camera-first, Arabic-first. Two capture modes (quick 4-photo scan and full 15-photo inspection), async processing with progress feedback, and a shareable report with trust score.

## Constraints

- **Team:** Solo developer (mostly)
- **Budget:** $0 — no paid services
- **Platform:** iOS + Android from single Flutter codebase
- **Language:** Egyptian Arabic first, all UI text in Arabic. App name "CheKar" stays in English.
- **Backend:** FastAPI at `{base_url}/api/v1/` — already built and tested
- **Beta:** 50-100 users invited from Egyptian car Facebook groups

## Brand Identity

### Colors

- **Primary:** #F97316 (bold orange)
- **Dark:** #1E1E2E (near-black)
- **Dark surface:** #272738 (cards on dark backgrounds)
- **Dark card:** #2E2E42 (elevated surfaces on dark)
- **Surface:** #FFF7ED (warm light)
- **Background:** #FAFAF9 (off-white)
- **Score colors:**
  - Good (85-100): #16A34A (green)
  - Mid (65-84): #EAB308 (yellow)
  - Warn (40-64): #F97316 (orange)
  - Bad (0-39): #DC2626 (red)

### Typography

- **Logo/Brand:** Saira (Latin, bold 700) — motorsport energy, automotive DNA, clean and sporty
- **Arabic UI:** Cairo (all weights 400-900) — Egyptian designer, modern geometric, proven in Egyptian apps
- **Font scale:**
  - Display/Hero: Cairo 900 (32-48sp)
  - Section headers: Cairo 700 (18-20sp)
  - Body: Cairo 500 (14-16sp)
  - Captions: Cairo 500 (12sp)

### Logo

Pure wordmark: `CHE` in white + `KAR` in orange (#F97316) + orange dot. Orbitron font, letter-spacing 3px. No icon — the wordmark IS the brand. Clean enough for app icon (just "CK" abbreviated).

### Design Direction — What Makes CheKar Unique

The app must NOT look like generic AI-generated design. These are the specific design principles applied to every screen:

**Noise texture:** Subtle grain overlay on all dark backgrounds (onboarding, camera, processing). Creates a physical, premium feel instead of flat digital surfaces. Applied as a semi-transparent PNG noise pattern or CSS/Flutter shader.

**Asymmetric layouts:** Break perfect centering. The trust score on the report screen bleeds slightly off-edge. Finding cards have unequal internal padding (more on right/RTL start). Controlled imperfection feels human and designed.

**Micro-animations:**
- Trust score number counts up from 0 to final value (e.g., 0 → 85) over 1.5 seconds with easing
- Finding cards slide in with staggered delays (100ms between each)
- Orange shutter button has a subtle breathing pulse animation
- Processing steps check-animate with a satisfying tick
- Score circle draws its colored border as an animated arc

**Photography-forward:** The report screen uses the user's own car photos as blurred background behind a dark overlay. Makes every report feel personal and specific, not templated.

**Arabic typography as design:** "اشتري بثقة" rendered at 36-40sp as a design statement, not a small label. Large Arabic text is a visual element — the curves and dots of Arabic script add organic beauty to otherwise geometric layouts.

**Orange glow effects:** Subtle orange radial gradients behind key interactive elements:
- Score circle gets an orange halo glow (spread 40px, opacity 15%)
- Shutter button has an ambient orange glow
- Active finding card gets a subtle orange edge glow on expand
- Onboarding logo has a radial orange gradient behind it

**Rounded vs angular tension:** Mix soft rounded cards (radius 16-20px) with sharp-cornered data elements (cost tables, sub-score bars). Soft buttons with precise monospace-style score numbers. The contrast between organic and precise creates visual interest.

**Dark → light transition:** Camera and processing screens are dark (#1E1E2E) — functional, focused, immersive. The report screen transitions to light (#FAFAF9) — readable, shareable, printable. The shift feels like "revealing the results" — emerging from the dark analysis into the light of clarity.

## App Architecture

```
lib/
├── main.dart                    # App entry, theme, locale, router
├── config/
│   ├── theme.dart               # Colors, text styles, component themes
│   ├── routes.dart              # GoRouter route definitions
│   └── api_config.dart          # Base URL, timeouts
├── services/
│   ├── api_service.dart         # HTTP client (dio) — all API calls
│   ├── storage_service.dart     # SharedPreferences — API key, settings
│   └── photo_service.dart       # Camera capture, image compression
├── models/
│   ├── inspection.dart          # Inspection data model
│   └── finding.dart             # Finding data model (from report JSON)
├── providers/
│   ├── auth_provider.dart       # API key state
│   ├── inspection_provider.dart # Current inspection state + polling
│   └── history_provider.dart    # Past inspections list
├── screens/
│   ├── onboarding_screen.dart   # Invite code entry + explainer
│   ├── home_screen.dart         # New inspection + history list
│   ├── capture_screen.dart      # Camera with overlay guides
│   ├── processing_screen.dart   # Animated AI progress
│   └── report_screen.dart       # Trust score + findings cards
├── widgets/
│   ├── score_card.dart          # Trust score hero widget
│   ├── finding_card.dart        # Expandable finding card
│   ├── camera_overlay.dart      # Corner frame + arrow guide
│   ├── capture_progress.dart    # Photo progress dots
│   └── mode_selector.dart       # Quick scan / Full inspection toggle
└── l10n/
    ├── app_ar.arb               # Arabic translations
    └── app_en.arb               # English translations (fallback)
```

### State Management: Riverpod

- `authProvider` — holds API key, persisted in SharedPreferences
- `inspectionProvider` — current inspection ID, status, photo count, results
- `historyProvider` — list of past inspections from local cache

### Navigation: GoRouter

```
/onboarding          → OnboardingScreen (shown once, if no API key)
/home                → HomeScreen (default after onboarding)
/capture/:mode       → CaptureScreen (mode = "quick" or "full")
/processing/:id      → ProcessingScreen (polls for results)
/report/:id          → ReportScreen (shows results)
```

## Screen Designs

### Screen 1: Onboarding

**When:** First launch only (no API key stored).

**Content:**
- Background: high-quality stock car photo (dark overlay at 85% opacity) — sets the automotive context immediately
- CheKar logo in Saira font (CHE white + KAR orange + dot)
- Large Arabic tagline as design element: "افحص عربيتك بالذكاء الاصطناعي" at reduced opacity
- Brief explainer: "صور العربية... هنفحصها بالذكاء الاصطناعي... هتعرف حالتها في دقيقة"
- Invite code text field (the API key)
- "ابدأ" (Start) button
- Validates the API key against the backend (`GET /health` with header, or any authenticated endpoint)

**After success:** Saves API key to SharedPreferences, navigates to `/home`.

### Screen 2: Home

**Layout:**
- App bar: "CheKar" logo, settings icon (future)
- Hero button: "فحص جديد" (New Inspection) — large, orange, prominent
- Below: inspection history list (cards showing car model, date, trust score, status)

**"فحص جديد" flow:**
1. Bottom sheet slides up with car info form:
   - الموديل (Car model) — text field with suggestions
   - السنة (Year) — number picker
   - الكيلومترات (Mileage) — number field
2. Mode selector: "فحص سريع (٤ صور)" or "فحص شامل (١٥ صورة)"
3. "يلا نبدأ" (Let's go) button → creates inspection via API → navigates to `/capture/{mode}`

**History list:**
- Each card shows: car model, date, trust score badge (colored), status
- Tap → navigates to `/report/{id}`
- Completed inspections show score, processing ones show spinner, failed ones show retry

### Screen 3: Guided Camera Capture

**Layout:** Full-screen camera viewfinder with overlay elements.

**Top bar (over camera):**
- Step counter: "٣ / ٤" (3 of 4) or "٧ / ١٥"
- Mode badge: "فحص سريع" or "فحص شامل"
- Close button (X) — confirms abandon

**Center overlay:**
- Corner bracket frame (orange, #F97316)
- Direction arrow showing which angle to shoot from
- These change per step

**Instruction area (below camera, above controls):**
- Arabic instruction: "صور العربية من الأمام" (Photograph the car from the front)
- Sub-text hint: "حط العربية جوه الإطار" (Put the car inside the frame)

**Bottom controls:**
- Shutter button (orange circle)
- Progress dots showing completed/remaining shots
- Gallery preview of last taken photo (small thumbnail)

**Photo sequence — Quick Scan (4 shots):**

| # | Shot | Arabic Instruction | Arrow Direction |
|---|------|-------------------|-----------------|
| 1 | Front center | صور العربية من الأمام | ↑ |
| 2 | Right side | صور الجنب اليمين | → |
| 3 | Rear center | صور العربية من ورا | ↓ |
| 4 | Left side | صور الجنب الشمال | ← |

**Photo sequence — Full Inspection (15 shots):**

| # | Shot | Arabic Instruction |
|---|------|-------------------|
| 1 | Front center | صور العربية من الأمام |
| 2 | Front-right 45° | صور من الأمام يمين |
| 3 | Right side full | صور الجنب اليمين كامل |
| 4 | Rear-right 45° | صور من ورا يمين |
| 5 | Rear center | صور العربية من ورا |
| 6 | Rear-left 45° | صور من ورا شمال |
| 7 | Left side full | صور الجنب الشمال كامل |
| 8 | Front-left 45° | صور من الأمام شمال |
| 9 | Hood open | افتح الكبوت وصوره |
| 10 | Dashboard | صور الطبلون |
| 11 | Odometer | صور العداد قريب |
| 12 | Interior front | صور المقاعد الأمامية |
| 13 | VIN plate | صور لوحة الشاسيه |
| 14 | Tires (front) | صور الكاوتش الأمامي |
| 15 | Door sill / undercarriage | صور أسفل الباب |

**Background upload:** Each photo uploads to `POST /inspections/{id}/photos` immediately after capture. A small upload indicator shows progress. If upload fails, retry silently. User doesn't wait — they continue taking the next photo.

**Completion:** After the last photo, show a brief "تمام! جاري تحليل العربية..." (Done! Analyzing the car...) then auto-navigate to `/processing/{id}`.

**Camera-only enforcement:** No gallery picker. Camera capture only. This is enforced in the app by only using the camera plugin, never the image picker.

### Screen 4: Processing

**When:** After all photos uploaded, waiting for AI pipeline to complete.

**Layout:** Dark background (#1E1E2E), centered animated content.

**Animation sequence (timed stages, not real progress):**
- 0-5s: "جاري تحليل الصور..." (Analyzing photos...) with YOLO-style scanning animation
- 5-15s: "بنفحص الدهان والخبطات..." (Checking paint and dents...)
- 15-25s: "بنقيم حالة العربية..." (Evaluating car condition...)
- 25s+: "التقرير جاهز تقريباً..." (Report almost ready...)

**Polling:** Every 3 seconds, calls `GET /inspections/{id}`. When status changes to `completed`, auto-navigates to `/report/{id}` with a brief success animation.

**On failure:** Shows error message with retry button. "حصل مشكلة، جرب تاني" (Something went wrong, try again).

### Screen 5: Report

**Layout:** Scrollable page, Arabic RTL.

**Hero section (top, always visible):**
- Large trust score number (64px, colored by range)
- Arabic label: "اشتري بثقة" / "فاوض على السعر" / "اعمل فحص ميكانيكي" / "ابعد عن العربية دي"
- Car info: model, year, mileage
- Mode badge: "فحص سريع" or "فحص شامل"

**Findings section:**
- Section header: "النتائج ({count} مشكلة)" — e.g., "النتائج (٤ مشاكل)"
- Each finding is a card, collapsed by default:
  - Finding type (Arabic) + severity badge (colored dot)
  - Location (Arabic)
  - Tap to expand:
    - Detailed description (Arabic, from Qwen)
    - Repair cost range: "٥٠٠ - ١,٥٠٠ جنيه"
    - Confidence level badge
- Cards sorted by severity (major first)

**Sub-scores section (collapsed by default):**
- Expandable section showing the 5 sub-scores:
  - حالة الهيكل (Body) — 92%
  - احتمال حادث (Accident) — 85%
  - احتمال غرق (Flood) — 100%
  - الحالة الميكانيكية (Mechanical) — 100%
  - تطابق المستندات (Documents) — 100%
- Sub-scores not assessed (quick scan) show "لم يتم الفحص" (Not assessed)

**Actions (bottom):**
- "شارك على واتساب" (Share on WhatsApp) — shares a text summary + trust score, or links to PDF
- "حمل التقرير PDF" (Download PDF Report) — downloads from `GET /inspections/{id}/report.pdf`

**Disclaimer (always visible at bottom):**
- "التقرير ده تقييم بالذكاء الاصطناعي بناءً على الصور — مش بديل عن الفحص الميكانيكي"

## API Integration

### Endpoints Used

| Screen | Endpoint | When |
|--------|----------|------|
| Onboarding | Any authenticated endpoint | Validate API key |
| Home (new) | `POST /api/v1/inspections` | Create inspection |
| Capture | `POST /api/v1/inspections/{id}/photos` | Upload each photo |
| Capture (done) | `POST /api/v1/inspections/{id}/run` | Trigger pipeline |
| Processing | `GET /api/v1/inspections/{id}` | Poll every 3s |
| Report | `GET /api/v1/inspections/{id}` | Get results |
| Report (PDF) | `GET /api/v1/inspections/{id}/report.pdf` | Download PDF |

### Error Handling

- **Network error during upload:** Retry silently up to 3 times, then show inline error on that photo's dot
- **API key rejected (401):** Navigate back to onboarding, clear stored key
- **Inspection failed:** Show error on processing screen with retry button
- **Timeout (>3 minutes polling):** Show "taking longer than usual" message, keep polling

## Dependencies

```yaml
dependencies:
  flutter_riverpod: ^2.5       # State management
  go_router: ^14.0              # Navigation
  dio: ^5.4                     # HTTP client
  camerawesome: ^2.0            # Camera with overlays
  shared_preferences: ^2.2      # Local storage
  flutter_localizations:        # Arabic RTL support
    sdk: flutter
  intl: ^0.19                   # Date/number formatting
  share_plus: ^9.0              # WhatsApp sharing
  flutter_image_compress: ^2.3  # Photo compression before upload
  path_provider: ^2.1           # File paths
```

## What This Does NOT Include

- User registration / accounts (API key only)
- Payment integration (Paymob/Fawry — deferred)
- Marketplace / car listings (separate sub-project)
- Photo anti-fraud enforcement (GPS, timestamps — deferred to v2)
- Offline mode / local caching of reports
- Push notifications ("your report is ready")
- Blur detection on-device (deferred — backend handles bad photos)
- Image forensics / manipulation detection
- Settings screen (language toggle, key management — deferred)
- Dark mode (app is already dark-themed for camera screens)
