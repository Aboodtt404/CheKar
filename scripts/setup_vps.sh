#!/bin/bash
set -euo pipefail

echo "=== CarCheck VPS Setup ==="
echo ""

# Config
MODELS_DIR="carcheck/data/models"
HF_CACHE="$HOME/hf_cache"
export HF_HOME="$HF_CACHE"

mkdir -p "$MODELS_DIR" "$HF_CACHE"

# 1. Install Python dependencies
echo "Installing dependencies..."
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
pip install vllm imagehash iterative-stratification pyyaml huggingface-hub

# 2. Download YOLO weights
echo ""
echo "Downloading YOLO11 car damage weights..."
python3 -c "
from huggingface_hub import hf_hub_download
path = hf_hub_download(
    repo_id='harpreetsahota/car-dd-segmentation-yolov11',
    filename='best.pt',
    local_dir='$MODELS_DIR',
)
print(f'Downloaded YOLO weights to: {path}')
"
cp "$MODELS_DIR/best.pt" "$MODELS_DIR/yolo11x-seg.pt" 2>/dev/null || true
echo "YOLO weights ready at $MODELS_DIR/yolo11x-seg.pt"

# 3. Done
echo ""
echo "=== Setup complete ==="
echo ""
echo "To start services, run: bash scripts/start_services.sh"
echo "To run an inspection:   carcheck inspect ./photos/ -m 'Nissan Sunny' -y 2019 -k 85000"
