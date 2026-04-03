#!/bin/bash
set -euo pipefail

echo "=== CarCheck VPS Setup ==="

echo "Installing vLLM..."
pip install vllm

echo "Downloading YOLO11 car damage weights..."
MODELS_DIR="carcheck/data/models"
mkdir -p "$MODELS_DIR"

pip install huggingface-hub
python -c "
from huggingface_hub import hf_hub_download
path = hf_hub_download(
    repo_id='harpreetsahota/car-dd-segmentation-yolov11',
    filename='best.pt',
    local_dir='$MODELS_DIR',
)
print(f'Downloaded YOLO weights to: {path}')
"

mv "$MODELS_DIR/best.pt" "$MODELS_DIR/yolo11x-seg.pt" 2>/dev/null || true

echo "YOLO weights ready at $MODELS_DIR/yolo11x-seg.pt"
echo ""
echo "=== To start the Qwen3.5 vLLM server, run: ==="
echo ""
echo "vllm serve Qwen/Qwen3.5-122B-A10B-Instruct \\"
echo "  --host 0.0.0.0 \\"
echo "  --port 8000 \\"
echo "  --tensor-parallel-size 1 \\"
echo "  --max-model-len 32768 \\"
echo "  --gpu-memory-utilization 0.4 \\"
echo "  --trust-remote-code"
echo ""
echo "=== Then run carcheck: ==="
echo ""
echo "carcheck inspect ./test_photos/ --car-model 'Nissan Sunny' --year 2019 --mileage 85000"
