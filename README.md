# CarCheck — فحص سيارات بالذكاء الاصطناعي

AI-powered used car inspection for the Egyptian market.

## Setup

```bash
git clone <repo-url>
cd CheKar
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"

# Download YOLO weights and setup VPS
bash scripts/setup_vps.sh

# Start vLLM server (in a separate terminal)
vllm serve Qwen/Qwen3.5-122B-A10B-Instruct \
  --port 8000 \
  --gpu-memory-utilization 0.4 \
  --trust-remote-code
```

## Usage

```bash
# Full inspection (Arabic output by default)
carcheck inspect ./photos/ \
  --car-model "Nissan Sunny" --year 2019 --mileage 85000

# With PDF report
carcheck inspect ./photos/ \
  --car-model "Nissan Sunny" --year 2019 --mileage 85000 \
  --output-pdf report.pdf

# YOLO detection only (quick test, no VLM needed)
carcheck detect ./photos/
```

## Tests

```bash
pytest carcheck/tests/ -v
```
