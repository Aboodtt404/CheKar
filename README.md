# CheKar — AI Car Inspection for Egypt

CheKar uses AI to inspect used cars from photos. Take 8-12 photos of a car, get a graded report showing exterior condition, paint issues, accident signs, and repair cost estimates — all in Egyptian Arabic.

## How It Works

1. **Seller** photographs the car using the guided camera flow
2. **AI** analyzes photos with YOLO damage detection + Qwen vision model
3. **Report** shows a letter grade (A-F), traffic light status per category, and repair costs in EGP
4. **Buyer** knows what they're getting before seeing the car in person

## What It Assesses

| Category | What It Checks |
| ---------- | --------------- |
| حالة الطلاء | Scratches, paint fading, repaint detection |
| حالة الهيكل | Dents, structural deformation, panel gaps |
| الزجاج والإضاءة | Cracked glass, broken headlights/taillights |
| الداخلية | Seat wear, flood indicators, dashboard condition |
| إشارات حوادث | Repaint patterns, panel misalignment, accident history |
| المستندات | Odometer vs wear consistency, year/model verification |

## What It Cannot Assess (at the moment)

- Engine, transmission, brakes, suspension — needs a mechanic
- Electrical systems — needs diagnostic tools
- Undercarriage — needs a lift
- Odometer accuracy — not guaranteed from photos

## Tech Stack

- **AI:** YOLO11 (damage detection) + Qwen3.5-27B-FP8 (vision analysis with cross-checking)
- **Backend:** FastAPI + Huey (SQLite job queue) on a single VPS
- **App:** Flutter (iOS + Android)
- **Language:** Egyptian Arabic first, English secondary

## Project Structure

```text
carcheck/           # Python backend — AI pipeline, API, scoring
  pipeline/         # YOLO + Qwen detection and analysis
  scoring/          # Letter grade + traffic light grading system
  api/              # FastAPI endpoints + Huey worker
  report/           # Arabic JSON + PDF report generation
app/                # Flutter mobile app
training/           # YOLO fine-tuning pipeline
scripts/            # VPS setup and service management
```

## Quick Start

```bash
# Local development (no GPU needed)
bash scripts/setup_local.sh
source .venv/bin/activate && source .env.local
carcheck detect ./photos/

# VPS deployment (full AI pipeline)
bash scripts/setup_vps.sh
bash scripts/start_services.sh
```

## Status

Beta — testing with real cars in Egypt.
