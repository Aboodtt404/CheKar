#!/bin/bash
set -euo pipefail

echo "=== CarCheck Local Dev Setup ==="
echo "For testing on a regular PC (no big GPU needed)"
echo ""

# 1. Python environment
echo "Setting up Python environment..."
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"

# 2. Download lightweight YOLO weights (nano model, ~6MB)
echo ""
echo "Downloading YOLO11n weights (lightweight)..."
MODELS_DIR="carcheck/data/models"
mkdir -p "$MODELS_DIR"
python3 -c "
from ultralytics import YOLO
model = YOLO('yolo11n.pt')  # auto-downloads ~6MB nano model
print('YOLO11n downloaded')
"

# 3. Install Ollama (if not present)
if ! command -v ollama &>/dev/null; then
    echo ""
    echo "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
fi

# 4. Pull small Qwen model for local testing
echo ""
echo "Pulling Qwen3.5 4B model (~2.5GB download)..."
ollama pull qwen3.5:4b

# 5. Load env
echo ""
echo "=== Setup Complete ==="
echo ""
echo "To start local services:"
echo "  ollama serve                     # terminal 1 (if not already running)"
echo "  source .env.local                # load local config"
echo "  carcheck detect ./test_photos/   # YOLO only test"
echo "  carcheck inspect ./test_photos/ -m 'Nissan Sunny' -y 2019 -k 85000  # full pipeline"
echo ""
echo "Local config uses:"
echo "  YOLO: yolo11n.pt (nano, CPU, 640px)"
echo "  VLM:  qwen3.5:4b via Ollama (2.5GB RAM)"
echo ""
echo "Note: Ollama serves an OpenAI-compatible API at localhost:11434/v1"
echo "      The .env.local file configures carcheck to use it automatically."
