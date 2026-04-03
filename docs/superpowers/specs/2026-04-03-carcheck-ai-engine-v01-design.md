# CarCheck AI Engine v0.1 — CLI Proof of Concept

**Date:** 2026-04-03
**Status:** Draft
**Sub-Project:** 1 of N (AI Engine validation before Flutter app, backend API, payments, etc.)

## Purpose

Validate that AI-powered used car inspection works on Egyptian cars from phone photos before building any product infrastructure. This is a Python CLI tool that takes car photos, runs them through a two-stage AI pipeline, and outputs a structured Arabic-first inspection report with a trust score and repair cost estimates.

Everything runs self-hosted on a VPS (RTX PRO 6000, 98GB VRAM, 123GB RAM, Ubuntu 24.04). $0 in external API costs.

## Constraints

- **Team:** 2 people, mostly solo developer
- **Budget:** $0 external costs (VPS already rented via vast.ai)
- **Language:** Arabic-first (Egyptian dialect), English as secondary option
- **Monetization:** Deferred — free inspections for beta validation first
- **Scope:** CLI tool only — no web UI, no mobile app, no auth, no payments

## Architecture

```
Input: Folder of car photos (up to 15, following capture sequence)
                    │
                    ▼
        ┌─────────────────────┐
        │  Image Preprocessor  │  Resize, normalize, quality check
        └──────────┬──────────┘
                    │
                    ▼
          ┌─────────────────┐
          │   YOLO11-seg    │  Damage detection + segmentation masks
          │   (~50ms/img)   │  6 classes: dent, scratch, crack, etc.
          └────────┬────────┘
                    │
                    ▼
        ┌─────────────────────┐
        │  Image Annotator    │  Overlay YOLO masks onto photos
        └──────────┬──────────┘
                    │
                    ▼
     ┌──────────────────────────┐
     │  Qwen3.5-122B-A10B      │  3 sequential calls:
     │  Call 1: Exterior        │  → damage severity, repaint, panels
     │  Call 2: Interior/Docs   │  → odometer OCR, flood, wear
     │  Call 3: Report Gen      │  → Arabic report + cost estimates
     └────────────┬─────────────┘
                   │
                   ▼
   ┌─────────────────────────────────┐
   │        Result Merger            │
   └──────────────┬──────────────────┘
                   │
                   ▼
   ┌─────────────────────────────────┐
   │      Trust Score Calculator     │
   └──────────────┬──────────────────┘
                   │
          ┌────────┴────────┐
          ▼                 ▼
    ┌───────────┐    ┌───────────┐
    │   JSON    │    │    PDF    │
    │  Output   │    │  Report   │
    └───────────┘    └───────────┘
```

YOLO runs first (~50ms per image, negligible latency), then Qwen receives the YOLO-annotated photos as input. Both models share the same GPU — YOLO uses ~4GB, Qwen ~30GB, no conflict on 98GB VRAM.

The pipeline is sequential: Preprocessor → YOLO → Annotate photos with YOLO masks → Qwen (3 calls) → Merge results → Score → Report.

## Stage 1: YOLO11 Damage Detection & Segmentation

### Model

- **Architecture:** YOLO11x-seg (instance segmentation variant)
- **Starting weights:** `harpreetsahota/car-dd-segmentation-yolov11` from HuggingFace (79.2% mask mAP50 out of the box)
- **Why YOLO11 over YOLOv8:** Better at small/occluded damage, native segmentation support, pre-trained car damage weights available

### Class List — CarDD 6-Class Standard

The de facto standard across academic papers, Roboflow datasets, and GitHub projects. Using this standard maximizes compatibility with existing labeled data.

| ID | Class | Arabic Name | Benchmark mAP50 |
|----|-------|-------------|-----------------|
| 0 | Dent | خبطة | 69.2% |
| 1 | Scratch | خدش | 90.5% |
| 2 | Crack | شرخ | 62.0% |
| 3 | Glass Shatter | زجاج مكسور | 99.4% |
| 4 | Lamp Broken | لمبة مكسورة | 89.5% |
| 5 | Tire Flat | كاوتش فاضي | 95.9% |

### Training Strategy

1. **Immediate:** Download pre-trained YOLO11x-seg weights and test on Egyptian car photos — validate transfer quality before any training
2. **If transfer is sufficient (>65% mAP50 on Egyptian test set):** Use as-is for v0.1, fine-tune later
3. **If transfer is insufficient:** Merge datasets for retraining:
   - CarDD original (~4,000 images)
   - car-DD-coco from Roboflow (compatible class scheme, CC BY 4.0)
   - Curacel AI dataset (6,839 images)
   - Total: ~14,000+ images with compatible labels
4. **Fine-tune** with Egyptian-specific augmentations: harsh sunlight, shadow contrast, brightness variation
5. **Continuously improve** with real Egyptian car photos from beta inspections

### Two-Model Pipeline (Phase 2 Enhancement)

For v0.1, only the damage segmentation model runs. In a future iteration, a second model (Ultralytics carparts-seg, 3,833 images, 23 car part classes) will be added to map damage to specific car parts (e.g., "dent on rear-left door") for part-specific cost estimates.

### Known Weakness

Dents are the hardest class at 69.2% mAP50. Minor, low-contrast dents under variable lighting are the primary failure mode — exactly the Egyptian outdoor scenario. Mitigation: aggressive data augmentation, Qwen provides a second opinion on damage severity, and guided photo capture (future app) will ensure consistent lighting guidance.

## Stage 2: Qwen3.5-122B-A10B Vision Analysis

### Model

- **Architecture:** Qwen3.5-122B-A10B (MoE — 122B total params, 10B active at inference)
- **VRAM usage:** ~25-35GB
- **Serving:** vLLM inference server with OpenAI-compatible API
- **Why this model:** Latest generation (March 2026), best OCR benchmarks (93.1), improved spatial reasoning, MoE efficiency leaves 65GB+ free for YOLO and overhead

### Task Responsibilities

| Task | Input Photos | Confidence Level | Notes |
|------|-------------|-----------------|-------|
| Odometer OCR + wear cross-referencing | Odometer + pedal + seat + steering | HIGH | Headline strength of the model |
| Flood damage screening | Interior + door sill + undercarriage | MEDIUM | Good for obvious signs |
| Repaint hints | All exterior panels | LOW | Always flagged with "recommend physical inspection" |
| Year/model verification | Dashboard + badge + features vs. claimed year/trim | HIGH | OCR + knowledge reasoning |
| Damage severity assessment | YOLO-annotated photos (masks overlaid) | MEDIUM | Second opinion on YOLO detections |
| Repair cost estimation | Damage type + location + car model + cost DB | MEDIUM | Uses hardcoded Egyptian cost DB |
| Arabic report generation | All structured findings | MEDIUM | Egyptian dialect, needs quality monitoring |

### Prompt Architecture — Three Separate Calls

One giant prompt produces worse results than focused, specialized calls.

**Call 1 — Exterior Analysis:**
- Input: 8 exterior photos (with YOLO annotation masks overlaid) + car model/year
- System prompt: Arabic, expert Egyptian automotive inspector persona
- Task: Assess damage severity, repaint indicators, panel alignment hints
- Output: Structured JSON of exterior findings with confidence levels

**Call 2 — Interior & Documentation:**
- Input: Dashboard, odometer, interior, VIN, door sill, undercarriage photos
- System prompt: Arabic, same inspector persona
- Task: OCR odometer, verify year/model, assess wear-vs-mileage consistency, check flood indicators
- Output: Structured JSON of interior/documentation findings

**Call 3 — Report Generation:**
- Input: Structured JSON from Calls 1 & 2 + Egyptian cost DB JSON
- System prompt: Arabic report writer, Egyptian dialect
- Task: Generate full Arabic inspection report with cost estimates, trust score explanation, and recommended actions
- Output: Arabic narrative text for each finding + summary

**Why three calls:** Keeps each prompt focused for better accuracy. Each call has a tuned system prompt. If one fails, retry just that call. Call 3 is pure text generation from structured data — could use a lighter model in the future.

### Arabic Dialect Strategy

- All system prompts explicitly instruct: "اكتب بالعامية المصرية، زي ميكانيكي مصري بيشرح لزبون"
- Few-shot examples in Egyptian Arabic included in prompts
- Technical terms use common Egyptian workshop language (e.g., "رفرف" not "حاجز الطين", "كبوت" not "غطاء المحرك")
- Numbers in Arabic context: "٢,٥٠٠ - ٤,٠٠٠ جنيه"
- English technical terms kept where Egyptians actually use them (e.g., "PDR", "ABS")

## Trust Score Algorithm

### Formula

```
Trust Score = (Body × 0.30) + (Accident × 0.25) + (Flood × 0.15)
            + (Mechanical × 0.15) + (Docs × 0.15)
```

Each sub-score starts at 100 and gets deducted based on findings. Floor is 0 per sub-score. Total range: 0-100.

### Deduction Rules

**Severity classification:** YOLO's CarDD classes detect damage type (dent, scratch, etc.) without severity. Severity is determined by two signals:
- **Mask area size:** Small mask (<2% of panel area) = minor, large mask (>2%) = major. Thresholds calibrated during beta.
- **Qwen assessment:** In Call 1 (Exterior Analysis), Qwen reviews each YOLO detection and classifies severity as minor/major based on visual context.

**Body Condition (30% weight):**

| Finding | Deduction | Source | Severity Determination |
|---------|-----------|--------|----------------------|
| Minor dent (per instance) | -3 | YOLO + Qwen | Mask area < 2% of panel |
| Major dent (per instance) | -8 | YOLO + Qwen | Mask area >= 2% of panel |
| Minor scratch (per instance) | -2 | YOLO + Qwen | Mask area < 2% of panel |
| Deep scratch (per instance) | -5 | YOLO + Qwen | Mask area >= 2% of panel |
| Rust/crack (per instance) | -7 | YOLO | Any size — always significant |
| Cracked windshield | -10 | YOLO | Any detection |
| Broken light (per instance) | -6 | YOLO | Any detection |
| Flat/worn tire (per instance) | -5 | YOLO | Any detection |

**Accident Probability (25% weight):**

| Finding | Deduction | Source |
|---------|-----------|--------|
| Possible repaint (LOW confidence) | -15 | Qwen |
| Likely repaint (MEDIUM confidence) | -30 | Qwen |
| Panel misalignment hint | -20 | Qwen |
| Multiple adjacent panels damaged | -10 | YOLO + Qwen |

**Flood Probability (15% weight):**

| Finding | Deduction | Source |
|---------|-----------|--------|
| Water stain indicators | -25 | Qwen |
| Corrosion in unusual locations | -20 | Qwen |
| Mud residue under seats/trunk | -30 | Qwen |
| Multiple flood indicators combined | -40 | Qwen |

**Mechanical Visible (15% weight):**

| Finding | Deduction | Source |
|---------|-----------|--------|
| Visible oil leak | -15 | Qwen |
| Belt/hose deterioration | -10 | Qwen |
| Engine bay corrosion | -12 | Qwen |
| Battery corrosion | -8 | Qwen |

**Documentation Consistency (15% weight):**

| Finding | Deduction | Source |
|---------|-----------|--------|
| Odometer vs. wear mismatch | -30 | Qwen |
| Year/model verification failed | -40 | Qwen |
| VIN unreadable | -10 | Qwen |

### Score Interpretation

| Range | Arabic Label | English | Recommended Action |
|-------|-------------|---------|-------------------|
| 85-100 | اشتري بثقة | Buy Confidently | Minor cosmetic issues at most |
| 65-84 | فاوض على السعر | Negotiate Price | Issues found, report shows repair costs |
| 40-64 | اعمل فحص ميكانيكي | Get Mechanic Inspection | Significant concerns, photos can't fully assess |
| 0-39 | ابعد عن العربية دي | Walk Away | Major red flags detected |

### Calibration Plan

Deduction values in v0.1 are educated guesses. Calibration process:
1. Run first 100-200 inspections for free with real buyers from Egyptian car Facebook groups
2. Follow up: "Did the score match reality after you bought the car?"
3. Track false positives (score too low) and false negatives (score too high)
4. Tune weights and deduction values based on real feedback
5. Publish accuracy metrics once statistically significant

### Handling AI Limitations Honestly

- Every finding shows its confidence level (HIGH / MEDIUM / LOW)
- LOW confidence findings (repaint, panel gaps) always include: "ننصح بفحص ميكانيكي للتأكد"
- The report includes a disclaimer: "التقرير ده تقييم بالذكاء الاصطناعي بناءً على الصور — مش بديل عن الفحص الميكانيكي"
- The score is transparent — users see exactly which findings caused deductions

## Repair Cost Database (v0.1)

A hardcoded JSON file with rough estimates for the top 5 Egyptian car models (P0 priority). Prices are ranges, not exact numbers. All values in EGP. More models added in future iterations.

### Covered Models (P0 — v0.1)

Nissan Sunny, Hyundai Elantra, Hyundai Verna, Chevrolet Optra, Toyota Corolla

Cost estimates for unlisted models fall back to generic ranges (not model-specific).

### Sample Cost Entries

```json
{
  "dent_repair_pdr": {
    "cairo": [500, 1500],
    "alexandria": [400, 1200],
    "unit": "per_panel",
    "notes_ar": "حسب حجم الخبطة ومكانها"
  },
  "single_panel_repaint": {
    "cairo": [2000, 4500],
    "alexandria": [1500, 3500],
    "unit": "per_panel",
    "notes_ar": "حسب نوع الدهان وموديل العربية"
  },
  "windshield_replacement": {
    "cairo": [3500, 8000],
    "alexandria": [3000, 7000],
    "unit": "per_unit",
    "notes_ar": "أصلي أغلى من الصيني"
  }
}
```

### Limitations

- All prices are rough estimates and need field validation
- Prices fluctuate with EGP exchange rate (parts are imported)
- Regional pricing only covers Cairo and Alexandria for v0.1
- No model-specific pricing yet (a Sunny bumper costs different from a Corolla bumper)
- Refresh plan: quarterly updates, community-reported prices in future versions

## CLI Tool Structure

### Usage

```bash
# Basic inspection (Arabic output by default)
carcheck inspect ./photos/nissan-sunny-2019/ \
  --car-model "Nissan Sunny" --year 2019 --mileage 85000

# With all output options
carcheck inspect ./photos/ \
  --car-model "Hyundai Verna" --year 2020 --mileage 45000 \
  --output-json report.json \
  --output-pdf report.pdf \
  --lang ar                    # ar (default) or en

# Quick test with pre-trained weights
carcheck detect ./photos/      # YOLO only, no Qwen, just show detections
```

### Project Structure

```
carcheck/
├── cli.py                      # Typer CLI entry point
├── pipeline/
│   ├── preprocessor.py         # Image validation, resize, quality check
│   ├── yolo_detector.py        # YOLO11-seg inference, returns detections
│   ├── image_annotator.py      # Draws YOLO masks onto photos for Qwen input
│   ├── vlm_analyzer.py         # Qwen3.5 API calls (3-step prompt chain)
│   └── result_merger.py        # Combines YOLO + Qwen outputs
├── scoring/
│   ├── trust_score.py          # Weighted scoring algorithm
│   └── deductions.py           # Deduction rules configuration
├── costs/
│   ├── cost_db.json            # Egyptian repair cost database
│   └── estimator.py            # Maps damage findings → cost ranges
├── report/
│   ├── generator.py            # Orchestrates report creation
│   ├── pdf_builder.py          # WeasyPrint PDF with Arabic RTL layout
│   ├── templates/              # HTML/CSS report templates (Arabic-first)
│   └── json_schema.py          # Pydantic models for structured output
├── data/
│   ├── prompts/                # Qwen system/user prompt templates (Arabic)
│   │   ├── exterior_analysis.txt
│   │   ├── interior_docs.txt
│   │   └── report_generation.txt
│   └── models/                 # YOLO11 weights directory
├── config.py                   # vLLM endpoint, model paths, settings
└── tests/                      # Test photos + expected outputs
    ├── test_photos/
    └── test_pipeline.py
```

### Dependencies

- `ultralytics` — YOLO11 inference
- `openai` — vLLM client (OpenAI-compatible API)
- `weasyprint` — PDF generation with Arabic RTL support
- `Pillow` — Image processing and annotation
- `typer` — CLI framework
- `pydantic` — Data validation and JSON schema
- `arabic-reshaper` + `python-bidi` — Arabic text rendering in PDF

### JSON Output Schema (Arabic-first)

All user-facing keys and values are in Arabic. Internal processing uses English keys.

```json
{
  "نتيجة_الفحص": {
    "درجة_الثقة": 72,
    "التصنيف": "فاوض على السعر",
    "السيارة": {
      "الموديل": "نيسان صني",
      "السنة": 2019,
      "الكيلومترات_المعلنة": 85000
    },
    "النتائج": [
      {
        "النوع": "خدش عميق",
        "الموقع": "الباب الخلفي الأيسر",
        "الخطورة": "متوسط",
        "مستوى_الثقة": "عالي",
        "تكلفة_الإصلاح": {"من": 2000, "إلى": 4500, "العملة": "جنيه"},
        "المصدر": "YOLO"
      }
    ],
    "ملخص": "العربية حالتها كويسة بشكل عام...",
    "التحذيرات": ["ننصح بفحص ميكانيكي للتأكد من حالة الدهان"],
    "إخلاء_مسؤولية": "التقرير ده تقييم بالذكاء الاصطناعي بناءً على الصور — مش بديل عن الفحص الميكانيكي"
  }
}
```

## VPS Deployment

### Infrastructure (all on one machine)

| Service | VRAM | RAM | Purpose |
|---------|------|-----|---------|
| vLLM (Qwen3.5-122B-A10B) | ~30GB | ~20GB | Vision LLM inference server |
| YOLO11x-seg | ~4GB | ~2GB | Damage detection inference |
| Total GPU usage | ~34GB | — | Leaves 64GB VRAM headroom |

### Services

- **vLLM:** Runs as a persistent service, OpenAI-compatible API on localhost
- **YOLO:** Loaded in-process by the CLI tool (no separate server needed for v0.1)
- No database needed for v0.1 (stateless CLI)
- No Redis/queue needed for v0.1 (single request at a time)

## What This Sub-Project Does NOT Include

These are explicitly deferred to future sub-projects:

- Flutter mobile app
- Guided camera capture flow
- Backend API (FastAPI)
- User authentication
- Payment integration (Paymob/Fawry)
- Anti-fraud verification (GPS, timestamps, device fingerprint)
- Web dashboard
- B2B features
- Mechanic verification tier
- Car parts segmentation model (Model 2 in two-model pipeline)
- Image forensics / manipulation detection
- Photo scraping pipeline (separate tooling task)

## Success Criteria for v0.1

1. **YOLO detects damage on Egyptian car photos** with reasonable accuracy (>60% mAP50 on a manually verified test set of 50 Egyptian car photos)
2. **Qwen reads odometers correctly** from dashboard photos (>90% OCR accuracy)
3. **Qwen produces coherent Egyptian Arabic reports** that a native speaker would find natural and useful
4. **Trust score feels reasonable** to 3+ car-savvy Egyptians who review the reports against their own judgment
5. **End-to-end pipeline runs** on the VPS without OOM or timeout issues for a set of 15 photos
6. **PDF report looks professional** with proper Arabic RTL layout and annotated damage photos

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| YOLO pre-trained weights don't transfer well to Egyptian cars | Medium | Test immediately before investing in training. Fall back to merged dataset retraining. |
| Qwen3.5-122B-A10B not available on HuggingFace or doesn't run on vLLM | Medium | Fall back to Qwen3-VL-32B (confirmed available, well-tested, lower VRAM). |
| Arabic output sounds robotic/formal | Medium | Iterate on prompts with Egyptian dialect examples. Have native speaker review. |
| Dent detection too unreliable in outdoor Egyptian lighting | High | Aggressive augmentation. Qwen second opinion. Conservative scoring (better to miss a dent than hallucinate one). |
| 98GB VRAM not enough for concurrent Qwen + YOLO | Low | 34GB combined is well within budget. Monitor with nvidia-smi. |
| No test photos available to validate | High | Must scrape Egyptian car photos from classifieds ASAP. This is a blocking dependency. |
