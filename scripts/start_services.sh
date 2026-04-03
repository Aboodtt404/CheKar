#!/bin/bash
set -euo pipefail

echo "=== Starting CarCheck Services ==="

HF_CACHE="$HOME/hf_cache"
export HF_HOME="$HF_CACHE"
mkdir -p "$HF_CACHE"

cd "$(dirname "$0")/.."
source .venv/bin/activate

# 1. Start Ollama qwen3-coder (if ollama is available)
if command -v ollama &>/dev/null; then
    echo "Loading qwen3-coder in Ollama..."
    ollama run qwen3-coder:latest --keepalive 24h </dev/null &>/dev/null &
    sleep 5
    echo "  Ollama: $(ollama ps 2>/dev/null | tail -1)"
fi

# 2. Start vLLM with Qwen3.5-27B-FP8
echo "Starting vLLM (Qwen3.5-27B-FP8)..."
pkill -f "vllm serve" 2>/dev/null || true
sleep 2

nohup vllm serve Qwen/Qwen3.5-27B-FP8 \
    --host 0.0.0.0 \
    --port 8000 \
    --max-model-len 16384 \
    --gpu-memory-utilization 0.5 \
    --trust-remote-code \
    --download-dir "$HF_CACHE" \
    --enforce-eager \
    > "$HOME/vllm.log" 2>&1 &

echo "  vLLM PID: $!"
echo "  Log: ~/vllm.log"
echo ""
echo "Waiting for vLLM to load (this takes ~2 minutes)..."
for i in $(seq 1 60); do
    if curl -s http://localhost:8000/v1/models &>/dev/null; then
        echo "  vLLM is ready!"
        break
    fi
    sleep 5
done

# 3. Show GPU status
echo ""
echo "=== GPU Status ==="
nvidia-smi --query-gpu=memory.used,memory.free,memory.total --format=csv,noheader
echo ""
echo "=== Services Ready ==="
echo "vLLM API: http://localhost:8000/v1"
echo ""
echo "Test: carcheck detect ./test_photos/"
echo "Full: carcheck inspect ./photos/ -m 'Nissan Sunny' -y 2019 -k 85000"
