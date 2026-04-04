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
import shutil
model = YOLO('yolo11n.pt')  # auto-downloads ~6MB nano model
shutil.copy('yolo11n.pt', '$MODELS_DIR/yolo11n.pt')
print('YOLO11n downloaded to $MODELS_DIR/')
"

# 3. Install Ollama (if not present)
if ! command -v ollama &>/dev/null; then
    echo ""
    echo "Installing Ollama (requires sudo)..."
    # Install zstd first if missing (needed by Ollama installer)
    if ! command -v zstd &>/dev/null; then
        echo "Installing zstd dependency..."
        sudo apt-get install -y zstd 2>/dev/null || sudo dnf install -y zstd 2>/dev/null || echo "Please install zstd manually: sudo apt-get install zstd"
    fi
    curl -fsSL https://ollama.com/install.sh | sh
fi

# 4. Pull small Qwen model for local testing
echo ""
echo "Pulling Qwen3.5 4B model (~2.5GB download)..."
ollama pull qwen3.5:4b

# 5. Done
echo ""
echo "=== Setup Complete ==="
echo ""
echo "To run CheKar:"
echo "  source .venv/bin/activate          # activate Python environment"
echo "  source .env.local                  # load local config"
echo "  carcheck detect ./test_photos/     # YOLO only test"
echo "  carcheck inspect ./photos/ -m 'Nissan Sunny' -y 2019 -k 85000  # full pipeline"
echo ""
echo "Or all in one line:"
echo "  source .venv/bin/activate && source .env.local && carcheck detect ./test_photos/"
