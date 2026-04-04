#!/bin/bash
echo "=== Stopping CarCheck Services ==="

pkill -f "vllm serve" 2>/dev/null && echo "vLLM stopped" || echo "vLLM not running"
ollama stop qwen3-coder 2>/dev/null && echo "Ollama qwen3-coder stopped" || echo "Ollama not running"
pkill -f "uvicorn carcheck" 2>/dev/null && echo "FastAPI stopped" || echo "FastAPI not running"
pkill -f "huey_consumer" 2>/dev/null && echo "Huey stopped" || echo "Huey not running"

sleep 2
echo ""
echo "GPU memory: $(nvidia-smi --query-gpu=memory.used --format=csv,noheader)"
