#!/bin/bash
set -e

# ── YOLO Retrain Script ─────────────────────────────────────────────────────
# Run on VPS: downloads VehiDE, prepares merged dataset, trains YOLO11x-seg
#
# Prerequisites:
#   - Kaggle API configured (pip install kaggle, ~/.kaggle/kaggle.json)
#   - vLLM stopped (need full GPU for training)
#   - ~20GB free disk space for datasets
#
# Usage:
#   bash scripts/retrain_yolo.sh
# ─────────────────────────────────────────────────────────────────────────────

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

DATASETS_DIR="$PROJECT_ROOT/quality_check"
OUTPUT_DIR="$PROJECT_ROOT"

echo "============================================================"
echo "CheKar YOLO Retrain Pipeline"
echo "============================================================"

# ── Step 0: Stop vLLM to free GPU ──
echo ""
echo "[0/5] Checking GPU availability..."
if pgrep -f vllm > /dev/null 2>&1; then
    echo "  vLLM is running. Stop it first to free GPU:"
    echo "    bash scripts/stop_services.sh"
    echo "  Or: kill \$(pgrep -f vllm)"
    exit 1
fi
echo "  GPU is free."

# ── Step 1: Download VehiDE dataset ──
echo ""
echo "[1/5] Downloading VehiDE dataset from Kaggle..."
VEHIDE_DIR="$DATASETS_DIR/vehide"
if [ -d "$VEHIDE_DIR" ] && [ "$(ls -A $VEHIDE_DIR 2>/dev/null)" ]; then
    echo "  VehiDE already downloaded at $VEHIDE_DIR — skipping"
else
    mkdir -p "$VEHIDE_DIR"
    # Download from Kaggle
    pip install -q kaggle 2>/dev/null || true
    kaggle datasets download -d hendrichscullen/vehide-dataset-automatic-vehicle-damage-detection \
        -p "$VEHIDE_DIR" --unzip
    echo "  Downloaded to $VEHIDE_DIR"
fi

# ── Step 2: Download base weights ──
echo ""
echo "[2/5] Checking base weights..."
WEIGHTS="yolo11x-seg.pt"
if [ ! -f "$WEIGHTS" ]; then
    echo "  Downloading YOLO11x-seg pretrained weights..."
    pip install -q ultralytics 2>/dev/null || true
    python -c "from ultralytics import YOLO; YOLO('yolo11x-seg.pt')"
fi
echo "  Weights ready: $WEIGHTS"

# ── Step 3: Prepare merged dataset ──
echo ""
echo "[3/5] Running data pipeline (merge + dedup + split)..."
pip install -q imagehash iterative-stratification 2>/dev/null || true
python -m training.prepare_data "$DATASETS_DIR" "$OUTPUT_DIR"

TRAINING_DATA="$OUTPUT_DIR/training_data"
if [ ! -f "$TRAINING_DATA/data.yaml" ]; then
    echo "  ERROR: data.yaml not generated. Check pipeline output above."
    exit 1
fi
echo "  Dataset ready at $TRAINING_DATA"

# ── Step 4: Train ──
echo ""
echo "[4/5] Starting YOLO11x-seg training..."
echo "  Config: AdamW, lr0=0.0001, cls=0.3, dfl=1.7, multi_scale, overlap_mask"
echo "  This will take several hours. Monitor with: tail -f runs/finetune/v2_merged/results.csv"
echo ""

python -m training.train \
    --data "$TRAINING_DATA/data.yaml" \
    --weights "$WEIGHTS" \
    --name "v2_merged" \
    --epochs 300 \
    --imgsz 1024

# ── Step 5: Evaluate ──
echo ""
echo "[5/5] Evaluating..."
BEST_WEIGHTS="runs/finetune/v2_merged/weights/best.pt"

if [ -f "$BEST_WEIGHTS" ]; then
    python -m training.evaluate \
        --weights "$BEST_WEIGHTS" \
        --data "$TRAINING_DATA/data.yaml" \
        --hires-dir test_results/hires 2>/dev/null || true

    echo ""
    echo "============================================================"
    echo "Training complete!"
    echo "Best weights: $BEST_WEIGHTS"
    echo ""
    echo "To deploy:"
    echo "  cp $BEST_WEIGHTS carcheck/data/models/yolo11x-finetuned.pt"
    echo "  # Then restart Huey worker"
    echo "============================================================"
else
    echo "  ERROR: Best weights not found at $BEST_WEIGHTS"
    exit 1
fi
