import os
from pathlib import Path
from pydantic import BaseModel


class Settings(BaseModel):
    # Paths
    project_root: Path = Path(__file__).parent.parent
    models_dir: Path = Path(__file__).parent / "data" / "models"
    prompts_dir: Path = Path(__file__).parent / "data" / "prompts"
    cost_db_path: Path = Path(__file__).parent / "costs" / "cost_db.json"

    # YOLO
    yolo_weights: str = os.getenv("CARCHECK_YOLO_WEIGHTS", "yolo11x-seg.pt")
    yolo_confidence: float = 0.25
    yolo_iou: float = 0.45
    yolo_img_size: int = int(os.getenv("CARCHECK_YOLO_IMGSZ", "1024"))
    yolo_device: str = os.getenv("CARCHECK_YOLO_DEVICE", "cpu")

    # vLLM / Qwen
    vlm_base_url: str = os.getenv("CARCHECK_VLM_URL", "http://localhost:8000/v1")
    vlm_model: str = os.getenv("CARCHECK_VLM_MODEL", "Qwen/Qwen3.5-27B-FP8")
    vlm_max_tokens: int = 2048
    vlm_temperature: float = 0.1

    # Image preprocessing
    max_image_dimension: int = 2048
    min_image_dimension: int = 640
    jpeg_quality: int = 85

    # Scoring
    severity_threshold_pct: float = 2.0  # mask area % of panel for minor/major split

    # Output
    default_lang: str = "ar"


settings = Settings()
