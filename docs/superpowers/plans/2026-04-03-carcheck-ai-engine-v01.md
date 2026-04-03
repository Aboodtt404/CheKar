# CarCheck AI Engine v0.1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Python CLI tool that takes car photos, runs YOLO11 damage detection + Qwen3.5 vision analysis, and outputs Arabic-first inspection reports with trust scores and repair cost estimates.

**Architecture:** Sequential pipeline — Image Preprocessor → YOLO11-seg (damage detection) → Image Annotator (overlay masks) → Qwen3.5-122B-A10B (3 VLM calls: exterior analysis, interior/docs, report generation) → Result Merger → Trust Score Calculator → JSON + PDF Report. All self-hosted on VPS with 98GB VRAM.

**Tech Stack:** Python 3.11+, ultralytics (YOLO11), openai (vLLM client), WeasyPrint (PDF), Pillow (images), Typer (CLI), Pydantic (schemas), vLLM (model serving)

**Spec:** `docs/superpowers/specs/2026-04-03-carcheck-ai-engine-v01-design.md`

---

## File Map

```
carcheck/
├── __init__.py
├── cli.py                          # Typer CLI — inspect + detect commands
├── config.py                       # Settings: vLLM endpoint, model paths, thresholds
├── models.py                       # All Pydantic data models (shared across pipeline)
├── pipeline/
│   ├── __init__.py
│   ├── preprocessor.py             # Image validation, resize, quality check
│   ├── yolo_detector.py            # YOLO11-seg wrapper — load model, run inference
│   ├── image_annotator.py          # Draw YOLO masks onto photos for Qwen input
│   ├── vlm_analyzer.py             # Qwen3.5 API client — 3 prompt calls
│   └── result_merger.py            # Combine YOLO detections + Qwen analysis
├── scoring/
│   ├── __init__.py
│   ├── trust_score.py              # Weighted scoring algorithm
│   └── deductions.py               # Deduction rules config (dataclass, not magic numbers)
├── costs/
│   ├── __init__.py
│   ├── cost_db.json                # Egyptian repair cost database
│   └── estimator.py                # Map damage type + car model → cost range
├── report/
│   ├── __init__.py
│   ├── generator.py                # Orchestrate JSON + PDF output
│   ├── pdf_builder.py              # WeasyPrint PDF with Arabic RTL
│   ├── json_output.py              # Arabic-keyed JSON serialization
│   └── templates/
│       └── report.html             # HTML template for PDF rendering
├── data/
│   ├── prompts/
│   │   ├── exterior_analysis.txt   # System + user prompt for Call 1
│   │   ├── interior_docs.txt       # System + user prompt for Call 2
│   │   └── report_generation.txt   # System + user prompt for Call 3
│   └── models/                     # YOLO11 weights (downloaded, not committed)
│       └── .gitkeep
├── tests/
│   ├── __init__.py
│   ├── conftest.py                 # Shared fixtures: sample detections, findings
│   ├── test_preprocessor.py
│   ├── test_yolo_detector.py
│   ├── test_image_annotator.py
│   ├── test_trust_score.py
│   ├── test_deductions.py
│   ├── test_cost_estimator.py
│   ├── test_result_merger.py
│   ├── test_json_output.py
│   ├── test_vlm_analyzer.py
│   └── test_photos/                # Small test images (committed)
│       └── .gitkeep
├── pyproject.toml                  # Project metadata + dependencies
└── README.md                       # Setup + usage instructions
```

---

## Task 1: Project Scaffold & Configuration

**Files:**
- Create: `pyproject.toml`
- Create: `carcheck/__init__.py`
- Create: `carcheck/config.py`
- Create: `carcheck/tests/__init__.py`
- Create: `carcheck/tests/conftest.py`
- Create: all `__init__.py` files for subpackages
- Create: `.gitignore`

- [ ] **Step 1: Initialize git repo**

```bash
cd /home/abdood/CheKar
git init
```

- [ ] **Step 2: Create .gitignore**

Create `.gitignore`:

```gitignore
__pycache__/
*.pyc
*.pyo
.venv/
venv/
dist/
*.egg-info/
.eggs/
*.pt
*.pth
*.onnx
carcheck/data/models/*.pt
.env
.superpowers/
*.pdf
```

- [ ] **Step 3: Create pyproject.toml**

Create `pyproject.toml`:

```toml
[project]
name = "carcheck"
version = "0.1.0"
description = "AI-powered used car inspection for the Egyptian market"
requires-python = ">=3.11"
dependencies = [
    "typer>=0.12",
    "pydantic>=2.0",
    "Pillow>=10.0",
    "openai>=1.0",
    "ultralytics>=8.3",
    "weasyprint>=62.0",
    "arabic-reshaper>=3.0",
    "python-bidi>=0.6",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "pytest-cov>=5.0",
]

[project.scripts]
carcheck = "carcheck.cli:app"

[build-system]
requires = ["setuptools>=75.0"]
build-backend = "setuptools.backends._legacy:_Backend"

[tool.pytest.ini_options]
testpaths = ["carcheck/tests"]
pythonpath = ["."]
```

- [ ] **Step 4: Create config.py**

Create `carcheck/config.py`:

```python
from pathlib import Path
from pydantic import BaseModel


class Settings(BaseModel):
    # Paths
    project_root: Path = Path(__file__).parent.parent
    models_dir: Path = Path(__file__).parent / "data" / "models"
    prompts_dir: Path = Path(__file__).parent / "data" / "prompts"
    cost_db_path: Path = Path(__file__).parent / "costs" / "cost_db.json"

    # YOLO
    yolo_weights: str = "yolo11x-seg.pt"
    yolo_confidence: float = 0.25
    yolo_iou: float = 0.45
    yolo_img_size: int = 1024

    # vLLM / Qwen
    vlm_base_url: str = "http://localhost:8000/v1"
    vlm_model: str = "Qwen/Qwen3.5-122B-A10B-Instruct"
    vlm_max_tokens: int = 4096
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
```

- [ ] **Step 5: Create all __init__.py files and directory stubs**

Create these empty files:

- `carcheck/__init__.py`
- `carcheck/pipeline/__init__.py`
- `carcheck/scoring/__init__.py`
- `carcheck/costs/__init__.py`
- `carcheck/report/__init__.py`
- `carcheck/tests/__init__.py`
- `carcheck/data/prompts/` (directory)
- `carcheck/data/models/.gitkeep`
- `carcheck/tests/test_photos/.gitkeep`
- `carcheck/report/templates/` (directory)

- [ ] **Step 6: Create conftest.py with shared test fixtures**

Create `carcheck/tests/conftest.py`:

```python
import pytest
from PIL import Image
from pathlib import Path


@pytest.fixture
def sample_image(tmp_path: Path) -> Path:
    """Create a simple 800x600 test image."""
    img = Image.new("RGB", (800, 600), color=(128, 128, 128))
    path = tmp_path / "test_car.jpg"
    img.save(path, "JPEG")
    return path


@pytest.fixture
def sample_image_small(tmp_path: Path) -> Path:
    """Create an image below minimum dimension."""
    img = Image.new("RGB", (320, 240), color=(128, 128, 128))
    path = tmp_path / "too_small.jpg"
    img.save(path, "JPEG")
    return path


@pytest.fixture
def sample_photos_dir(tmp_path: Path) -> Path:
    """Create a directory with 3 test images."""
    photos = tmp_path / "photos"
    photos.mkdir()
    for i in range(3):
        img = Image.new("RGB", (800, 600), color=(100 + i * 50, 100, 100))
        (photos / f"photo_{i}.jpg").save(img, "JPEG")
    return photos
```

- [ ] **Step 7: Install dependencies and verify**

```bash
cd /home/abdood/CheKar
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
pytest --co  # collect tests, should find 0 tests with no errors
```

Expected: `no tests ran` with exit code 5 (no tests collected, not an error).

- [ ] **Step 8: Commit**

```bash
git add .gitignore pyproject.toml carcheck/
git commit -m "feat: project scaffold with config, deps, and test fixtures"
```

---

## Task 2: Pydantic Data Models

**Files:**
- Create: `carcheck/models.py`
- Create: `carcheck/tests/test_models.py`

These are the shared data structures used by every pipeline stage.

- [ ] **Step 1: Write failing tests for data models**

Create `carcheck/tests/test_models.py`:

```python
from carcheck.models import (
    Detection,
    Finding,
    SubScore,
    TrustScoreResult,
    InspectionInput,
    InspectionResult,
    ConfidenceLevel,
    Severity,
    FindingSource,
)


def test_detection_from_yolo():
    det = Detection(
        class_id=0,
        class_name="dent",
        class_name_ar="خبطة",
        confidence=0.87,
        bbox=[100, 200, 300, 400],
        mask_area_pixels=1500,
        image_area_pixels=480000,
    )
    assert det.mask_area_pct == pytest.approx(0.3125, rel=1e-2)
    assert det.class_name == "dent"


def test_detection_severity_minor():
    det = Detection(
        class_id=1,
        class_name="scratch",
        class_name_ar="خدش",
        confidence=0.9,
        bbox=[0, 0, 100, 100],
        mask_area_pixels=500,
        image_area_pixels=480000,
    )
    assert det.severity == Severity.MINOR  # 0.1% < 2% threshold


def test_detection_severity_major():
    det = Detection(
        class_id=0,
        class_name="dent",
        class_name_ar="خبطة",
        confidence=0.85,
        bbox=[0, 0, 200, 200],
        mask_area_pixels=15000,
        image_area_pixels=480000,
    )
    assert det.severity == Severity.MAJOR  # 3.1% > 2% threshold


def test_detection_severity_always_major_for_crack():
    det = Detection(
        class_id=2,
        class_name="crack",
        class_name_ar="شرخ",
        confidence=0.7,
        bbox=[0, 0, 50, 50],
        mask_area_pixels=100,
        image_area_pixels=480000,
    )
    assert det.severity == Severity.MAJOR  # crack is always major


def test_finding_creation():
    finding = Finding(
        type="خدش عميق",
        type_en="Deep scratch",
        location="الباب الخلفي الأيسر",
        location_en="Rear left door",
        severity=Severity.MAJOR,
        confidence=ConfidenceLevel.HIGH,
        source=FindingSource.YOLO,
        cost_min=2000,
        cost_max=4500,
    )
    assert finding.confidence == ConfidenceLevel.HIGH
    assert finding.cost_min == 2000


def test_sub_score_floor_at_zero():
    sub = SubScore(name="body", name_ar="حالة الهيكل", weight=0.30, base=100)
    sub.deduct(60)
    sub.deduct(60)
    assert sub.score == 0  # floor at 0, not -20


def test_trust_score_result():
    result = TrustScoreResult(
        total=72,
        label_ar="فاوض على السعر",
        label_en="Negotiate Price",
        sub_scores={
            "body": SubScore(name="body", name_ar="حالة الهيكل", weight=0.30, base=100),
        },
    )
    assert result.total == 72
    assert result.label_ar == "فاوض على السعر"


def test_inspection_input():
    inp = InspectionInput(
        photos_dir="/tmp/photos",
        car_model="Nissan Sunny",
        year=2019,
        mileage=85000,
        lang="ar",
    )
    assert inp.car_model == "Nissan Sunny"
    assert inp.lang == "ar"


import pytest
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest carcheck/tests/test_models.py -v
```

Expected: FAIL — `ModuleNotFoundError: No module named 'carcheck.models'`

- [ ] **Step 3: Implement data models**

Create `carcheck/models.py`:

```python
from __future__ import annotations

from enum import Enum
from pathlib import Path

from pydantic import BaseModel, computed_field

from carcheck.config import settings


class Severity(str, Enum):
    MINOR = "minor"
    MAJOR = "major"


class ConfidenceLevel(str, Enum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


class FindingSource(str, Enum):
    YOLO = "YOLO"
    QWEN = "Qwen"
    BOTH = "YOLO+Qwen"


# Classes where any detection is always MAJOR severity
_ALWAYS_MAJOR_CLASSES = {"crack", "glass_shatter", "lamp_broken", "tire_flat"}


CLASS_NAMES_AR = {
    "dent": "خبطة",
    "scratch": "خدش",
    "crack": "شرخ",
    "glass_shatter": "زجاج مكسور",
    "lamp_broken": "لمبة مكسورة",
    "tire_flat": "كاوتش فاضي",
}


class Detection(BaseModel):
    """A single YOLO detection from one image."""

    class_id: int
    class_name: str
    class_name_ar: str
    confidence: float
    bbox: list[float]  # [x1, y1, x2, y2]
    mask_area_pixels: int
    image_area_pixels: int
    image_path: str = ""

    @computed_field
    @property
    def mask_area_pct(self) -> float:
        if self.image_area_pixels == 0:
            return 0.0
        return (self.mask_area_pixels / self.image_area_pixels) * 100

    @computed_field
    @property
    def severity(self) -> Severity:
        if self.class_name in _ALWAYS_MAJOR_CLASSES:
            return Severity.MAJOR
        if self.mask_area_pct >= settings.severity_threshold_pct:
            return Severity.MAJOR
        return Severity.MINOR


class Finding(BaseModel):
    """A single inspection finding — from YOLO, Qwen, or both."""

    type: str  # Arabic display name
    type_en: str
    location: str  # Arabic location
    location_en: str
    severity: Severity
    confidence: ConfidenceLevel
    source: FindingSource
    cost_min: int | None = None
    cost_max: int | None = None
    note_ar: str = ""
    note_en: str = ""
    # Scoring metadata (set by VLM analyzer or result merger)
    finding_category: str = ""  # "accident", "flood", "mechanical", "docs"
    finding_key: str = ""       # key into deduction lookup tables


class SubScore(BaseModel):
    """One component of the trust score."""

    name: str
    name_ar: str
    weight: float
    base: int = 100
    score: int = 100
    deductions: list[tuple[str, int]] = []

    def deduct(self, amount: int, reason: str = "") -> None:
        self.deductions.append((reason, amount))
        self.score = max(0, self.score - amount)


class TrustScoreResult(BaseModel):
    """The complete trust score output."""

    total: int
    label_ar: str
    label_en: str
    sub_scores: dict[str, SubScore]


class InspectionInput(BaseModel):
    """Input parameters for an inspection run."""

    photos_dir: str
    car_model: str
    year: int
    mileage: int
    lang: str = "ar"
    region: str = "cairo"


class InspectionResult(BaseModel):
    """Complete output of an inspection pipeline run."""

    input: InspectionInput
    detections: list[Detection] = []
    findings: list[Finding] = []
    trust_score: TrustScoreResult | None = None
    summary_ar: str = ""
    summary_en: str = ""
    disclaimer_ar: str = "التقرير ده تقييم بالذكاء الاصطناعي بناءً على الصور — مش بديل عن الفحص الميكانيكي"
    disclaimer_en: str = "This is an AI assessment based on photos — not a substitute for mechanical inspection"
    warnings: list[str] = []
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
pytest carcheck/tests/test_models.py -v
```

Expected: All 9 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add carcheck/models.py carcheck/tests/test_models.py
git commit -m "feat: pydantic data models for detections, findings, scores, and inspection results"
```

---

## Task 3: Image Preprocessor

**Files:**
- Create: `carcheck/pipeline/preprocessor.py`
- Create: `carcheck/tests/test_preprocessor.py`

- [ ] **Step 1: Write failing tests**

Create `carcheck/tests/test_preprocessor.py`:

```python
import pytest
from pathlib import Path
from PIL import Image

from carcheck.pipeline.preprocessor import preprocess_image, validate_photos_dir


def test_preprocess_resizes_large_image(tmp_path: Path):
    img = Image.new("RGB", (4000, 3000), color=(128, 128, 128))
    path = tmp_path / "large.jpg"
    img.save(path, "JPEG")

    result = preprocess_image(path, tmp_path / "out")
    processed = Image.open(result)
    assert max(processed.size) <= 2048


def test_preprocess_keeps_small_image(tmp_path: Path):
    img = Image.new("RGB", (800, 600), color=(128, 128, 128))
    path = tmp_path / "ok.jpg"
    img.save(path, "JPEG")

    result = preprocess_image(path, tmp_path / "out")
    processed = Image.open(result)
    assert processed.size == (800, 600)


def test_preprocess_rejects_too_small(tmp_path: Path):
    img = Image.new("RGB", (320, 240), color=(128, 128, 128))
    path = tmp_path / "tiny.jpg"
    img.save(path, "JPEG")

    with pytest.raises(ValueError, match="too small"):
        preprocess_image(path, tmp_path / "out")


def test_preprocess_rejects_non_image(tmp_path: Path):
    path = tmp_path / "not_image.txt"
    path.write_text("hello")

    with pytest.raises(ValueError, match="not a valid image"):
        preprocess_image(path, tmp_path / "out")


def test_validate_photos_dir(tmp_path: Path):
    photos = tmp_path / "photos"
    photos.mkdir()
    for i in range(3):
        img = Image.new("RGB", (800, 600), color=(100, 100, 100))
        img.save(photos / f"photo_{i}.jpg", "JPEG")

    paths = validate_photos_dir(photos)
    assert len(paths) == 3


def test_validate_photos_dir_empty(tmp_path: Path):
    photos = tmp_path / "empty"
    photos.mkdir()

    with pytest.raises(ValueError, match="No valid images"):
        validate_photos_dir(photos)
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest carcheck/tests/test_preprocessor.py -v
```

Expected: FAIL — `ModuleNotFoundError`

- [ ] **Step 3: Implement preprocessor**

Create `carcheck/pipeline/preprocessor.py`:

```python
from pathlib import Path

from PIL import Image, UnidentifiedImageError

from carcheck.config import settings

_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def preprocess_image(image_path: Path, output_dir: Path) -> Path:
    """Validate and resize a single image. Returns path to processed image."""
    try:
        img = Image.open(image_path)
        img.verify()
        img = Image.open(image_path)  # reopen after verify
    except (UnidentifiedImageError, Exception) as e:
        raise ValueError(f"{image_path.name} is not a valid image: {e}")

    width, height = img.size
    if max(width, height) < settings.min_image_dimension:
        raise ValueError(
            f"{image_path.name} is too small ({width}x{height}). "
            f"Minimum dimension: {settings.min_image_dimension}px"
        )

    output_dir.mkdir(parents=True, exist_ok=True)

    if max(width, height) > settings.max_image_dimension:
        ratio = settings.max_image_dimension / max(width, height)
        new_size = (int(width * ratio), int(height * ratio))
        img = img.resize(new_size, Image.LANCZOS)

    img = img.convert("RGB")
    out_path = output_dir / f"{image_path.stem}.jpg"
    img.save(out_path, "JPEG", quality=settings.jpeg_quality)
    return out_path


def validate_photos_dir(photos_dir: Path) -> list[Path]:
    """Return sorted list of valid image paths in a directory."""
    if not photos_dir.is_dir():
        raise ValueError(f"{photos_dir} is not a directory")

    paths = sorted(
        p for p in photos_dir.iterdir()
        if p.suffix.lower() in _IMAGE_EXTENSIONS
    )

    if not paths:
        raise ValueError(f"No valid images found in {photos_dir}")

    return paths
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
pytest carcheck/tests/test_preprocessor.py -v
```

Expected: All 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add carcheck/pipeline/preprocessor.py carcheck/tests/test_preprocessor.py
git commit -m "feat: image preprocessor with validation, resize, and quality check"
```

---

## Task 4: YOLO Detector Wrapper

**Files:**
- Create: `carcheck/pipeline/yolo_detector.py`
- Create: `carcheck/tests/test_yolo_detector.py`

- [ ] **Step 1: Write tests**

Create `carcheck/tests/test_yolo_detector.py`:

```python
import pytest
from unittest.mock import MagicMock, patch
from pathlib import Path
from PIL import Image

from carcheck.pipeline.yolo_detector import YOLODetector, parse_yolo_results
from carcheck.models import Detection


def test_parse_yolo_results_empty():
    """No detections returns empty list."""
    mock_result = MagicMock()
    mock_result.boxes = MagicMock()
    mock_result.boxes.cls = []
    mock_result.boxes.conf = []
    mock_result.boxes.xyxy = []
    mock_result.masks = None
    mock_result.orig_shape = (600, 800)
    mock_result.path = "/tmp/test.jpg"

    detections = parse_yolo_results(mock_result, class_names={0: "dent", 1: "scratch"})
    assert detections == []


def test_parse_yolo_results_with_detections():
    """Parse a mocked YOLO result with one detection."""
    import numpy as np

    mock_result = MagicMock()
    mock_result.boxes.cls = np.array([0])
    mock_result.boxes.conf = np.array([0.87])
    mock_result.boxes.xyxy = np.array([[100, 200, 300, 400]])
    mock_mask = np.zeros((600, 800), dtype=np.uint8)
    mock_mask[200:400, 100:300] = 1  # 200x200 = 40000 pixels
    mock_result.masks.data = np.array([mock_mask])
    mock_result.orig_shape = (600, 800)
    mock_result.path = "/tmp/test.jpg"

    class_names = {0: "dent", 1: "scratch"}
    detections = parse_yolo_results(mock_result, class_names=class_names)

    assert len(detections) == 1
    assert detections[0].class_name == "dent"
    assert detections[0].class_name_ar == "خبطة"
    assert detections[0].confidence == pytest.approx(0.87, rel=1e-2)
    assert detections[0].mask_area_pixels == 40000
    assert detections[0].image_area_pixels == 480000


def test_yolo_detector_init_with_missing_weights():
    """Detector raises if weights file doesn't exist."""
    with pytest.raises(FileNotFoundError):
        YOLODetector(weights_path=Path("/nonexistent/model.pt"))
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest carcheck/tests/test_yolo_detector.py -v
```

Expected: FAIL — `ModuleNotFoundError`

- [ ] **Step 3: Implement YOLO detector**

Create `carcheck/pipeline/yolo_detector.py`:

```python
from __future__ import annotations

from pathlib import Path

import numpy as np

from carcheck.config import settings
from carcheck.models import Detection, CLASS_NAMES_AR


# CarDD 6-class standard
CARDD_CLASSES = {
    0: "dent",
    1: "scratch",
    2: "crack",
    3: "glass_shatter",
    4: "lamp_broken",
    5: "tire_flat",
}


def parse_yolo_results(
    result,
    class_names: dict[int, str] | None = None,
) -> list[Detection]:
    """Convert a single YOLO result object to a list of Detection models."""
    if class_names is None:
        class_names = CARDD_CLASSES

    boxes = result.boxes
    if len(boxes.cls) == 0:
        return []

    h, w = result.orig_shape
    image_area = h * w

    detections = []
    classes = boxes.cls.cpu().numpy() if hasattr(boxes.cls, "cpu") else np.array(boxes.cls)
    confs = boxes.conf.cpu().numpy() if hasattr(boxes.conf, "cpu") else np.array(boxes.conf)
    xyxys = boxes.xyxy.cpu().numpy() if hasattr(boxes.xyxy, "cpu") else np.array(boxes.xyxy)

    masks_data = None
    if result.masks is not None:
        masks_data = result.masks.data
        if hasattr(masks_data, "cpu"):
            masks_data = masks_data.cpu().numpy()

    for i in range(len(classes)):
        cls_id = int(classes[i])
        cls_name = class_names.get(cls_id, f"class_{cls_id}")

        mask_pixels = 0
        if masks_data is not None and i < len(masks_data):
            mask_pixels = int(np.sum(masks_data[i] > 0.5))

        detections.append(
            Detection(
                class_id=cls_id,
                class_name=cls_name,
                class_name_ar=CLASS_NAMES_AR.get(cls_name, cls_name),
                confidence=float(confs[i]),
                bbox=xyxys[i].tolist(),
                mask_area_pixels=mask_pixels,
                image_area_pixels=image_area,
                image_path=str(getattr(result, "path", "")),
            )
        )

    return detections


class YOLODetector:
    """Wrapper around ultralytics YOLO for car damage detection."""

    def __init__(self, weights_path: Path | None = None):
        if weights_path is None:
            weights_path = settings.models_dir / settings.yolo_weights

        if not weights_path.exists():
            raise FileNotFoundError(f"YOLO weights not found: {weights_path}")

        from ultralytics import YOLO

        self.model = YOLO(str(weights_path))
        self.class_names = CARDD_CLASSES

    def detect(self, image_paths: list[Path]) -> list[list[Detection]]:
        """Run inference on a list of images. Returns detections per image."""
        results = self.model(
            [str(p) for p in image_paths],
            conf=settings.yolo_confidence,
            iou=settings.yolo_iou,
            imgsz=settings.yolo_img_size,
            verbose=False,
        )

        all_detections = []
        for result in results:
            detections = parse_yolo_results(result, self.class_names)
            all_detections.append(detections)

        return all_detections
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
pytest carcheck/tests/test_yolo_detector.py -v
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add carcheck/pipeline/yolo_detector.py carcheck/tests/test_yolo_detector.py
git commit -m "feat: YOLO11 detector wrapper with CarDD 6-class parsing"
```

---

## Task 5: Image Annotator

**Files:**
- Create: `carcheck/pipeline/image_annotator.py`
- Create: `carcheck/tests/test_image_annotator.py`

- [ ] **Step 1: Write failing tests**

Create `carcheck/tests/test_image_annotator.py`:

```python
import pytest
from pathlib import Path
from PIL import Image
import numpy as np

from carcheck.pipeline.image_annotator import annotate_image
from carcheck.models import Detection


@pytest.fixture
def sample_detection() -> Detection:
    return Detection(
        class_id=0,
        class_name="dent",
        class_name_ar="خبطة",
        confidence=0.87,
        bbox=[100, 200, 300, 400],
        mask_area_pixels=5000,
        image_area_pixels=480000,
        image_path="/tmp/test.jpg",
    )


def test_annotate_image_creates_output(tmp_path: Path, sample_detection: Detection):
    img = Image.new("RGB", (800, 600), color=(128, 128, 128))
    src = tmp_path / "src.jpg"
    img.save(src, "JPEG")

    out_path = annotate_image(src, [sample_detection], tmp_path / "annotated")
    assert out_path.exists()
    annotated = Image.open(out_path)
    assert annotated.size == (800, 600)


def test_annotate_image_no_detections(tmp_path: Path):
    img = Image.new("RGB", (800, 600), color=(128, 128, 128))
    src = tmp_path / "src.jpg"
    img.save(src, "JPEG")

    out_path = annotate_image(src, [], tmp_path / "annotated")
    assert out_path.exists()
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest carcheck/tests/test_image_annotator.py -v
```

Expected: FAIL — `ModuleNotFoundError`

- [ ] **Step 3: Implement annotator**

Create `carcheck/pipeline/image_annotator.py`:

```python
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from carcheck.models import Detection, Severity

# Color map: class_name -> (R, G, B)
_COLORS = {
    "dent": (255, 100, 100),
    "scratch": (255, 200, 50),
    "crack": (255, 50, 50),
    "glass_shatter": (200, 50, 255),
    "lamp_broken": (50, 150, 255),
    "tire_flat": (255, 150, 0),
}

_DEFAULT_COLOR = (255, 100, 100)


def annotate_image(
    image_path: Path,
    detections: list[Detection],
    output_dir: Path,
) -> Path:
    """Draw detection bounding boxes and labels onto an image copy."""
    output_dir.mkdir(parents=True, exist_ok=True)
    img = Image.open(image_path).convert("RGB")
    draw = ImageDraw.Draw(img, "RGBA")

    for det in detections:
        color = _COLORS.get(det.class_name, _DEFAULT_COLOR)
        x1, y1, x2, y2 = det.bbox

        # Semi-transparent fill
        fill_color = (*color, 50)
        draw.rectangle([x1, y1, x2, y2], fill=fill_color, outline=color, width=3)

        # Label
        sev = "⚠" if det.severity == Severity.MAJOR else "•"
        label = f"{sev} {det.class_name_ar} ({det.confidence:.0%})"
        draw.text((x1 + 4, y1 + 4), label, fill=color)

    out_path = output_dir / f"{image_path.stem}_annotated.jpg"
    img.save(out_path, "JPEG", quality=90)
    return out_path
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
pytest carcheck/tests/test_image_annotator.py -v
```

Expected: All 2 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add carcheck/pipeline/image_annotator.py carcheck/tests/test_image_annotator.py
git commit -m "feat: image annotator draws YOLO detection boxes and labels"
```

---

## Task 6: Trust Score Calculator

**Files:**
- Create: `carcheck/scoring/deductions.py`
- Create: `carcheck/scoring/trust_score.py`
- Create: `carcheck/tests/test_deductions.py`
- Create: `carcheck/tests/test_trust_score.py`

- [ ] **Step 1: Write failing tests for deductions config**

Create `carcheck/tests/test_deductions.py`:

```python
from carcheck.scoring.deductions import (
    get_body_deduction,
    get_accident_deduction,
    get_flood_deduction,
    get_mechanical_deduction,
    get_docs_deduction,
)
from carcheck.models import Severity


def test_body_minor_dent():
    assert get_body_deduction("dent", Severity.MINOR) == 3


def test_body_major_dent():
    assert get_body_deduction("dent", Severity.MAJOR) == 8


def test_body_crack_always_7():
    assert get_body_deduction("crack", Severity.MINOR) == 7
    assert get_body_deduction("crack", Severity.MAJOR) == 7


def test_body_unknown_class():
    assert get_body_deduction("unknown_class", Severity.MINOR) == 0


def test_accident_repaint_low():
    assert get_accident_deduction("repaint_possible") == 15


def test_accident_repaint_likely():
    assert get_accident_deduction("repaint_likely") == 30


def test_flood_water_stain():
    assert get_flood_deduction("water_stain") == 25


def test_flood_multiple():
    assert get_flood_deduction("multiple_indicators") == 40


def test_mechanical_oil_leak():
    assert get_mechanical_deduction("oil_leak") == 15


def test_docs_odometer_mismatch():
    assert get_docs_deduction("odometer_mismatch") == 30
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest carcheck/tests/test_deductions.py -v
```

Expected: FAIL — `ModuleNotFoundError`

- [ ] **Step 3: Implement deductions config**

Create `carcheck/scoring/deductions.py`:

```python
from carcheck.models import Severity

# Body condition deductions: (class_name, severity) -> points
_BODY_DEDUCTIONS: dict[tuple[str, Severity], int] = {
    ("dent", Severity.MINOR): 3,
    ("dent", Severity.MAJOR): 8,
    ("scratch", Severity.MINOR): 2,
    ("scratch", Severity.MAJOR): 5,
    ("crack", Severity.MINOR): 7,
    ("crack", Severity.MAJOR): 7,
    ("glass_shatter", Severity.MINOR): 10,
    ("glass_shatter", Severity.MAJOR): 10,
    ("lamp_broken", Severity.MINOR): 6,
    ("lamp_broken", Severity.MAJOR): 6,
    ("tire_flat", Severity.MINOR): 5,
    ("tire_flat", Severity.MAJOR): 5,
}

_ACCIDENT_DEDUCTIONS: dict[str, int] = {
    "repaint_possible": 15,
    "repaint_likely": 30,
    "panel_misalignment": 20,
    "adjacent_panels_damaged": 10,
}

_FLOOD_DEDUCTIONS: dict[str, int] = {
    "water_stain": 25,
    "unusual_corrosion": 20,
    "mud_residue": 30,
    "multiple_indicators": 40,
}

_MECHANICAL_DEDUCTIONS: dict[str, int] = {
    "oil_leak": 15,
    "belt_deterioration": 10,
    "engine_corrosion": 12,
    "battery_corrosion": 8,
}

_DOCS_DEDUCTIONS: dict[str, int] = {
    "odometer_mismatch": 30,
    "year_model_failed": 40,
    "vin_unreadable": 10,
}


def get_body_deduction(class_name: str, severity: Severity) -> int:
    return _BODY_DEDUCTIONS.get((class_name, severity), 0)


def get_accident_deduction(finding_type: str) -> int:
    return _ACCIDENT_DEDUCTIONS.get(finding_type, 0)


def get_flood_deduction(finding_type: str) -> int:
    return _FLOOD_DEDUCTIONS.get(finding_type, 0)


def get_mechanical_deduction(finding_type: str) -> int:
    return _MECHANICAL_DEDUCTIONS.get(finding_type, 0)


def get_docs_deduction(finding_type: str) -> int:
    return _DOCS_DEDUCTIONS.get(finding_type, 0)
```

- [ ] **Step 4: Run deduction tests**

```bash
pytest carcheck/tests/test_deductions.py -v
```

Expected: All 10 tests PASS.

- [ ] **Step 5: Write failing tests for trust score calculator**

Create `carcheck/tests/test_trust_score.py`:

```python
import pytest
from carcheck.scoring.trust_score import calculate_trust_score
from carcheck.models import Detection, Finding, Severity, ConfidenceLevel, FindingSource


def test_perfect_score_no_findings():
    result = calculate_trust_score(detections=[], findings=[])
    assert result.total == 100
    assert result.label_ar == "اشتري بثقة"
    assert result.label_en == "Buy Confidently"


def test_minor_dent_deducts_from_body():
    detections = [
        Detection(
            class_id=0, class_name="dent", class_name_ar="خبطة",
            confidence=0.8, bbox=[0, 0, 100, 100],
            mask_area_pixels=500, image_area_pixels=480000,
        ),
    ]
    result = calculate_trust_score(detections=detections, findings=[])
    # Body sub-score: 100 - 3 = 97. Weighted: 97*0.30 = 29.1
    # Other sub-scores: 100 each. 100*0.25 + 100*0.15*3 = 70
    # Total: 29.1 + 70 = 99.1 -> 99
    assert result.total == 99


def test_multiple_findings_lower_score():
    detections = [
        Detection(
            class_id=0, class_name="dent", class_name_ar="خبطة",
            confidence=0.8, bbox=[0, 0, 200, 200],
            mask_area_pixels=20000, image_area_pixels=480000,  # major: 4.1%
        ),
        Detection(
            class_id=0, class_name="dent", class_name_ar="خبطة",
            confidence=0.7, bbox=[0, 0, 200, 200],
            mask_area_pixels=20000, image_area_pixels=480000,  # major
        ),
    ]
    findings = [
        Finding(
            type="احتمال إعادة دهان", type_en="Possible repaint",
            location="الرفرف الأمامي", location_en="Front fender",
            severity=Severity.MAJOR, confidence=ConfidenceLevel.LOW,
            source=FindingSource.QWEN, cost_min=None, cost_max=None,
        ),
    ]
    result = calculate_trust_score(detections=detections, findings=findings)
    assert result.total < 90  # should be noticeably lower


def test_flood_indicators_drop_score():
    findings = [
        Finding(
            type="بقع مياه", type_en="Water stains",
            location="المقاعد", location_en="Seats",
            severity=Severity.MAJOR, confidence=ConfidenceLevel.MEDIUM,
            source=FindingSource.QWEN,
            finding_category="flood", finding_key="water_stain",
        ),
    ]
    result = calculate_trust_score(detections=[], findings=findings)
    assert result.total < 100


def test_walk_away_score():
    findings = [
        Finding(
            type="عداد مش مطابق", type_en="Odometer mismatch",
            location="الطبلون", location_en="Dashboard",
            severity=Severity.MAJOR, confidence=ConfidenceLevel.HIGH,
            source=FindingSource.QWEN,
            finding_category="docs", finding_key="odometer_mismatch",
        ),
        Finding(
            type="إعادة دهان مؤكدة", type_en="Likely repaint",
            location="أكتر من لوحة", location_en="Multiple panels",
            severity=Severity.MAJOR, confidence=ConfidenceLevel.MEDIUM,
            source=FindingSource.QWEN,
            finding_category="accident", finding_key="repaint_likely",
        ),
        Finding(
            type="علامات غرق", type_en="Multiple flood indicators",
            location="الداخلية", location_en="Interior",
            severity=Severity.MAJOR, confidence=ConfidenceLevel.MEDIUM,
            source=FindingSource.QWEN,
            finding_category="flood", finding_key="multiple_indicators",
        ),
    ]
    result = calculate_trust_score(detections=[], findings=findings)
    assert result.total < 40
    assert result.label_ar == "ابعد عن العربية دي"


def test_score_interpretation_ranges():
    from carcheck.scoring.trust_score import get_score_label
    assert get_score_label(95) == ("اشتري بثقة", "Buy Confidently")
    assert get_score_label(75) == ("فاوض على السعر", "Negotiate Price")
    assert get_score_label(50) == ("اعمل فحص ميكانيكي", "Get Mechanic Inspection")
    assert get_score_label(20) == ("ابعد عن العربية دي", "Walk Away")
```

- [ ] **Step 6: Run tests to verify they fail**

```bash
pytest carcheck/tests/test_trust_score.py -v
```

Expected: FAIL — `ModuleNotFoundError`

- [ ] **Step 7: Implement trust score calculator**

Create `carcheck/scoring/trust_score.py`:

```python
from carcheck.models import (
    Detection,
    Finding,
    SubScore,
    TrustScoreResult,
)
from carcheck.scoring.deductions import (
    get_body_deduction,
    get_accident_deduction,
    get_flood_deduction,
    get_mechanical_deduction,
    get_docs_deduction,
)


def get_score_label(score: int) -> tuple[str, str]:
    """Return (arabic_label, english_label) for a trust score."""
    if score >= 85:
        return ("اشتري بثقة", "Buy Confidently")
    if score >= 65:
        return ("فاوض على السعر", "Negotiate Price")
    if score >= 40:
        return ("اعمل فحص ميكانيكي", "Get Mechanic Inspection")
    return ("ابعد عن العربية دي", "Walk Away")


def calculate_trust_score(
    detections: list[Detection],
    findings: list[Finding],
) -> TrustScoreResult:
    """Calculate the 0-100 trust score from detections and findings."""

    body = SubScore(name="body", name_ar="حالة الهيكل", weight=0.30)
    accident = SubScore(name="accident", name_ar="احتمال حادث", weight=0.25)
    flood = SubScore(name="flood", name_ar="احتمال غرق", weight=0.15)
    mechanical = SubScore(name="mechanical", name_ar="الحالة الميكانيكية", weight=0.15)
    docs = SubScore(name="docs", name_ar="تطابق المستندات", weight=0.15)

    # Apply YOLO detection deductions to body score
    for det in detections:
        amount = get_body_deduction(det.class_name, det.severity)
        if amount > 0:
            body.deduct(amount, f"{det.class_name_ar} ({det.severity.value})")

    # Apply Qwen finding deductions to appropriate sub-scores
    category_map = {
        "accident": (accident, get_accident_deduction),
        "flood": (flood, get_flood_deduction),
        "mechanical": (mechanical, get_mechanical_deduction),
        "docs": (docs, get_docs_deduction),
    }

    for finding in findings:
        cat = finding.finding_category
        key = finding.finding_key
        if cat in category_map and key:
            sub_score, deduction_fn = category_map[cat]
            amount = deduction_fn(key)
            if amount > 0:
                sub_score.deduct(amount, finding.type)

    sub_scores = {
        "body": body,
        "accident": accident,
        "flood": flood,
        "mechanical": mechanical,
        "docs": docs,
    }

    total = round(sum(s.score * s.weight for s in sub_scores.values()))
    label_ar, label_en = get_score_label(total)

    return TrustScoreResult(
        total=total,
        label_ar=label_ar,
        label_en=label_en,
        sub_scores=sub_scores,
    )
```

- [ ] **Step 8: Run all scoring tests**

```bash
pytest carcheck/tests/test_deductions.py carcheck/tests/test_trust_score.py -v
```

Expected: All tests PASS.

- [ ] **Step 9: Commit**

```bash
git add carcheck/scoring/ carcheck/tests/test_deductions.py carcheck/tests/test_trust_score.py
git commit -m "feat: trust score calculator with deduction rules and score interpretation"
```

---

## Task 7: Repair Cost Estimator

**Files:**
- Create: `carcheck/costs/cost_db.json`
- Create: `carcheck/costs/estimator.py`
- Create: `carcheck/tests/test_cost_estimator.py`

- [ ] **Step 1: Write failing tests**

Create `carcheck/tests/test_cost_estimator.py`:

```python
import pytest
from carcheck.costs.estimator import estimate_repair_cost


def test_dent_cost_cairo():
    cost = estimate_repair_cost("dent", region="cairo")
    assert cost is not None
    assert cost["min"] == 500
    assert cost["max"] == 1500


def test_scratch_cost_alexandria():
    cost = estimate_repair_cost("scratch", region="alexandria")
    assert cost is not None
    assert cost["min"] > 0


def test_unknown_damage_returns_none():
    cost = estimate_repair_cost("nonexistent_damage", region="cairo")
    assert cost is None


def test_unknown_region_falls_back_to_cairo():
    cost = estimate_repair_cost("dent", region="mansoura")
    assert cost is not None
    # Falls back to cairo prices
    assert cost["min"] == 500


def test_all_damage_types_have_costs():
    for damage_type in ["dent", "scratch", "crack", "glass_shatter", "lamp_broken", "tire_flat"]:
        cost = estimate_repair_cost(damage_type, region="cairo")
        assert cost is not None, f"Missing cost for {damage_type}"
        assert cost["min"] > 0
        assert cost["max"] > cost["min"]
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest carcheck/tests/test_cost_estimator.py -v
```

Expected: FAIL

- [ ] **Step 3: Create cost database JSON**

Create `carcheck/costs/cost_db.json`:

```json
{
  "dent": {
    "cairo": [500, 1500],
    "alexandria": [400, 1200],
    "unit": "per_panel",
    "notes_ar": "حسب حجم الخبطة ومكانها — PDR أرخص من السمكرة"
  },
  "scratch": {
    "cairo": [300, 1000],
    "alexandria": [250, 800],
    "unit": "per_panel",
    "notes_ar": "الخدش البسيط ممكن يتلم بالبولش — العميق محتاج دهان"
  },
  "crack": {
    "cairo": [2000, 6000],
    "alexandria": [1500, 5000],
    "unit": "per_panel",
    "notes_ar": "الشروخ غالبا محتاجة لحام وسمكرة ودهان"
  },
  "glass_shatter": {
    "cairo": [3500, 8000],
    "alexandria": [3000, 7000],
    "unit": "per_unit",
    "notes_ar": "أصلي أغلى من الصيني بكتير"
  },
  "lamp_broken": {
    "cairo": [2000, 12000],
    "alexandria": [1800, 10000],
    "unit": "per_unit",
    "notes_ar": "اللمبة LED والبروجيكتور أغلى بكتير من العادية"
  },
  "tire_flat": {
    "cairo": [1200, 3500],
    "alexandria": [1100, 3200],
    "unit": "per_tire",
    "notes_ar": "حسب الماركة والمقاس"
  },
  "repaint_single_panel": {
    "cairo": [2000, 4500],
    "alexandria": [1500, 3500],
    "unit": "per_panel",
    "notes_ar": "حسب نوع الدهان وموديل العربية"
  },
  "repaint_full_body": {
    "cairo": [15000, 30000],
    "alexandria": [12000, 25000],
    "unit": "per_car",
    "notes_ar": "الدهان الميتاليك أغلى"
  }
}
```

- [ ] **Step 4: Implement cost estimator**

Create `carcheck/costs/estimator.py`:

```python
import json
from pathlib import Path

from carcheck.config import settings

_cost_data: dict | None = None


def _load_cost_db() -> dict:
    global _cost_data
    if _cost_data is None:
        with open(settings.cost_db_path, "r", encoding="utf-8") as f:
            _cost_data = json.load(f)
    return _cost_data


def estimate_repair_cost(
    damage_type: str,
    region: str = "cairo",
) -> dict | None:
    """Look up repair cost range for a damage type and region.

    Returns {"min": int, "max": int, "unit": str, "notes_ar": str} or None.
    Falls back to cairo if region not found.
    """
    db = _load_cost_db()

    if damage_type not in db:
        return None

    entry = db[damage_type]
    prices = entry.get(region)
    if prices is None:
        prices = entry.get("cairo")
    if prices is None:
        return None

    return {
        "min": prices[0],
        "max": prices[1],
        "unit": entry.get("unit", ""),
        "notes_ar": entry.get("notes_ar", ""),
    }
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
pytest carcheck/tests/test_cost_estimator.py -v
```

Expected: All 5 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add carcheck/costs/ carcheck/tests/test_cost_estimator.py
git commit -m "feat: Egyptian repair cost database and estimator with cairo/alexandria pricing"
```

---

## Task 8: VLM Analyzer (Qwen3.5 Prompt Chain)

**Files:**
- Create: `carcheck/pipeline/vlm_analyzer.py`
- Create: `carcheck/data/prompts/exterior_analysis.txt`
- Create: `carcheck/data/prompts/interior_docs.txt`
- Create: `carcheck/data/prompts/report_generation.txt`
- Create: `carcheck/tests/test_vlm_analyzer.py`

- [ ] **Step 1: Create Arabic prompt templates**

Create `carcheck/data/prompts/exterior_analysis.txt`:

```
أنت خبير فحص سيارات مصري محترف. بتفحص صور عربية مستعملة وبتقيم حالتها الخارجية.

## المعلومات:
- الموديل: {car_model}
- السنة: {year}
- الكيلومترات المعلنة: {mileage}

## نتائج الفحص الآلي (YOLO):
{yolo_detections_json}

## المطلوب منك:
1. **تقييم الأضرار**: لكل ضرر اتكشف بالفحص الآلي، قيّم خطورته (بسيط / متوسط / خطير) بناءً على الصور
2. **كشف إعادة الدهان**: قارن لون وملمس الدهان بين اللوحات المتجاورة. دور على:
   - فرق في اللون بين لوحتين جنب بعض
   - ملمس "قشر برتقال" مختلف عن باقي العربية
   - رذاذ دهان على الكاوتش أو الكرومات
3. **محاذاة اللوحات**: لو في فرق في الفراغات بين اللوحات أو لوحة بارزة

## طريقة الرد:
رد بـ JSON فقط بالشكل ده:
```json
{
  "exterior_findings": [
    {
      "type": "اسم المشكلة بالعربي",
      "type_en": "English name",
      "location": "مكانها بالعربي",
      "location_en": "English location",
      "severity": "minor|major",
      "confidence": "high|medium|low",
      "finding_category": "accident|body",
      "finding_key": "repaint_possible|repaint_likely|panel_misalignment|adjacent_panels_damaged",
      "description_ar": "وصف بالعامية المصرية"
    }
  ]
}
```

مهم: اكتب بالعامية المصرية زي ميكانيكي بيشرح لزبون. استخدم كلمات زي "رفرف" و"كبوت" و"شنطة" مش المصطلحات الفصحى.
```

Create `carcheck/data/prompts/interior_docs.txt`:

```
أنت خبير فحص سيارات مصري محترف. بتفحص الصور الداخلية والمستندات.

## المعلومات:
- الموديل: {car_model}
- السنة: {year}
- الكيلومترات المعلنة: {mileage}

## المطلوب منك:
1. **قراءة العداد**: اقرأ رقم الكيلومترات من صورة العداد
2. **تطابق العداد مع الاستهلاك**: قارن الكيلومترات المعلنة مع:
   - حالة دواسة البنزين والفرامل (متآكلة = كيلومترات كتير)
   - حالة الدركسيون (لامع/متآكل)
   - حالة المقاعد (مترهلة/سليمة)
3. **علامات الغرق**: دور على:
   - بقع مياه على القماش أو السقف
   - صدأ في أماكن غريبة (تحت الكراسي، مفصلات الأبواب)
   - طين أو رمل في الشنطة أو تحت الكراسي
4. **التحقق من السنة والموديل**: تأكد إن الطبلون والفيتشرز متوافقة مع السنة والموديل المعلن

## طريقة الرد:
رد بـ JSON فقط:
```json
{
  "odometer_reading": 85000,
  "odometer_matches_wear": true,
  "interior_findings": [
    {
      "type": "اسم المشكلة",
      "type_en": "English name",
      "location": "المكان",
      "location_en": "English location",
      "severity": "minor|major",
      "confidence": "high|medium|low",
      "finding_category": "flood|mechanical|docs",
      "finding_key": "water_stain|unusual_corrosion|mud_residue|multiple_indicators|oil_leak|belt_deterioration|engine_corrosion|battery_corrosion|odometer_mismatch|year_model_failed|vin_unreadable",
      "description_ar": "وصف بالعامية"
    }
  ],
  "year_model_verified": true
}
```

اكتب بالعامية المصرية.
```

Create `carcheck/data/prompts/report_generation.txt`:

```
أنت كاتب تقارير فحص سيارات مصري. بتكتب تقرير واضح وبسيط للمشتري.

## معلومات العربية:
- الموديل: {car_model}
- السنة: {year}
- الكيلومترات: {mileage}

## نتائج الفحص:
{findings_json}

## قاعدة بيانات أسعار الإصلاح:
{cost_db_json}

## المطلوب:
1. اكتب ملخص قصير (٢-٣ جمل) عن حالة العربية بشكل عام
2. لكل مشكلة، اكتب:
   - وصف واضح بالعامية
   - تقدير تكلفة الإصلاح بالجنيه المصري (استخدم قاعدة البيانات)
   - نصيحة للمشتري
3. اكتب النصيحة النهائية بناءً على درجة الثقة: {trust_score}

## طريقة الرد:
```json
{
  "summary_ar": "ملخص بالعامية المصرية",
  "findings_with_costs": [
    {
      "type": "اسم المشكلة",
      "description_ar": "شرح بالعامية",
      "cost_min": 500,
      "cost_max": 1500,
      "advice_ar": "نصيحة بالعامية"
    }
  ],
  "total_estimated_repair_cost": {"min": 2000, "max": 6000},
  "final_advice_ar": "النصيحة النهائية"
}
```

اكتب كل حاجة بالعامية المصرية. استخدم "جنيه" مش "ج.م". استخدم أرقام عربية عادية (1234 مش ١٢٣٤) في الـ JSON.
```

- [ ] **Step 2: Write tests for VLM analyzer**

Create `carcheck/tests/test_vlm_analyzer.py`:

```python
import pytest
from unittest.mock import patch, MagicMock, AsyncMock
from pathlib import Path

from carcheck.pipeline.vlm_analyzer import (
    VLMAnalyzer,
    build_exterior_prompt,
    build_interior_prompt,
    build_report_prompt,
    parse_vlm_json_response,
)


def test_build_exterior_prompt():
    prompt = build_exterior_prompt(
        car_model="Nissan Sunny",
        year=2019,
        mileage=85000,
        yolo_detections_json='[{"class": "dent"}]',
    )
    assert "Nissan Sunny" in prompt
    assert "2019" in prompt
    assert "85000" in prompt
    assert "dent" in prompt


def test_build_interior_prompt():
    prompt = build_interior_prompt(
        car_model="Nissan Sunny",
        year=2019,
        mileage=85000,
    )
    assert "Nissan Sunny" in prompt
    assert "85000" in prompt


def test_build_report_prompt():
    prompt = build_report_prompt(
        car_model="Nissan Sunny",
        year=2019,
        mileage=85000,
        findings_json="[]",
        cost_db_json="{}",
        trust_score=72,
    )
    assert "72" in prompt


def test_parse_vlm_json_response_clean():
    raw = '{"exterior_findings": []}'
    parsed = parse_vlm_json_response(raw)
    assert parsed == {"exterior_findings": []}


def test_parse_vlm_json_response_with_markdown():
    raw = '```json\n{"exterior_findings": []}\n```'
    parsed = parse_vlm_json_response(raw)
    assert parsed == {"exterior_findings": []}


def test_parse_vlm_json_response_invalid():
    raw = "This is not JSON at all"
    with pytest.raises(ValueError, match="parse"):
        parse_vlm_json_response(raw)
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
pytest carcheck/tests/test_vlm_analyzer.py -v
```

Expected: FAIL

- [ ] **Step 4: Implement VLM analyzer**

Create `carcheck/pipeline/vlm_analyzer.py`:

```python
from __future__ import annotations

import base64
import json
import re
from pathlib import Path

from openai import OpenAI

from carcheck.config import settings
from carcheck.models import Finding, ConfidenceLevel, Severity, FindingSource


def _load_prompt(name: str) -> str:
    path = settings.prompts_dir / f"{name}.txt"
    return path.read_text(encoding="utf-8")


def build_exterior_prompt(
    car_model: str,
    year: int,
    mileage: int,
    yolo_detections_json: str,
) -> str:
    template = _load_prompt("exterior_analysis")
    return template.format(
        car_model=car_model,
        year=year,
        mileage=mileage,
        yolo_detections_json=yolo_detections_json,
    )


def build_interior_prompt(
    car_model: str,
    year: int,
    mileage: int,
) -> str:
    template = _load_prompt("interior_docs")
    return template.format(
        car_model=car_model,
        year=year,
        mileage=mileage,
    )


def build_report_prompt(
    car_model: str,
    year: int,
    mileage: int,
    findings_json: str,
    cost_db_json: str,
    trust_score: int,
) -> str:
    template = _load_prompt("report_generation")
    return template.format(
        car_model=car_model,
        year=year,
        mileage=mileage,
        findings_json=findings_json,
        cost_db_json=cost_db_json,
        trust_score=trust_score,
    )


def parse_vlm_json_response(raw: str) -> dict:
    """Extract JSON from a VLM response that may contain markdown fences."""
    cleaned = raw.strip()

    # Strip markdown code fences
    match = re.search(r"```(?:json)?\s*\n?(.*?)```", cleaned, re.DOTALL)
    if match:
        cleaned = match.group(1).strip()

    try:
        return json.loads(cleaned)
    except json.JSONDecodeError as e:
        raise ValueError(f"Failed to parse VLM JSON response: {e}\nRaw: {raw[:500]}")


def _image_to_base64_url(image_path: Path) -> str:
    data = image_path.read_bytes()
    b64 = base64.b64encode(data).decode("utf-8")
    return f"data:image/jpeg;base64,{b64}"


def _build_image_messages(image_paths: list[Path]) -> list[dict]:
    """Build the image content blocks for an OpenAI-style vision request."""
    content = []
    for p in image_paths:
        content.append({
            "type": "image_url",
            "image_url": {"url": _image_to_base64_url(p)},
        })
    return content


class VLMAnalyzer:
    """Client for the Qwen3.5 VLM served via vLLM."""

    def __init__(self):
        self.client = OpenAI(
            base_url=settings.vlm_base_url,
            api_key="not-needed",  # vLLM doesn't require a key
        )
        self.model = settings.vlm_model

    def _call(self, system: str, user_text: str, image_paths: list[Path] | None = None) -> str:
        """Make a single VLM API call."""
        user_content: list[dict] = []

        if image_paths:
            user_content.extend(_build_image_messages(image_paths))

        user_content.append({"type": "text", "text": user_text})

        response = self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user_content},
            ],
            max_tokens=settings.vlm_max_tokens,
            temperature=settings.vlm_temperature,
        )
        return response.choices[0].message.content

    def analyze_exterior(
        self,
        image_paths: list[Path],
        car_model: str,
        year: int,
        mileage: int,
        yolo_detections_json: str,
    ) -> list[Finding]:
        """Call 1: Exterior analysis with YOLO-annotated photos."""
        system = "أنت خبير فحص سيارات مصري. رد بـ JSON فقط."
        user_text = build_exterior_prompt(car_model, year, mileage, yolo_detections_json)

        raw = self._call(system, user_text, image_paths)
        parsed = parse_vlm_json_response(raw)

        findings = []
        for f in parsed.get("exterior_findings", []):
            findings.append(Finding(
                type=f.get("type", ""),
                type_en=f.get("type_en", ""),
                location=f.get("location", ""),
                location_en=f.get("location_en", ""),
                severity=Severity(f.get("severity", "minor")),
                confidence=ConfidenceLevel(f.get("confidence", "medium")),
                source=FindingSource.QWEN,
                finding_category=f.get("finding_category", ""),
                finding_key=f.get("finding_key", ""),
                note_ar=f.get("description_ar", ""),
            ))
        return findings

    def analyze_interior(
        self,
        image_paths: list[Path],
        car_model: str,
        year: int,
        mileage: int,
    ) -> tuple[list[Finding], dict]:
        """Call 2: Interior & documentation analysis. Returns (findings, metadata)."""
        system = "أنت خبير فحص سيارات مصري. رد بـ JSON فقط."
        user_text = build_interior_prompt(car_model, year, mileage)

        raw = self._call(system, user_text, image_paths)
        parsed = parse_vlm_json_response(raw)

        metadata = {
            "odometer_reading": parsed.get("odometer_reading"),
            "odometer_matches_wear": parsed.get("odometer_matches_wear", True),
            "year_model_verified": parsed.get("year_model_verified", True),
        }

        findings = []
        for f in parsed.get("interior_findings", []):
            findings.append(Finding(
                type=f.get("type", ""),
                type_en=f.get("type_en", ""),
                location=f.get("location", ""),
                location_en=f.get("location_en", ""),
                severity=Severity(f.get("severity", "minor")),
                confidence=ConfidenceLevel(f.get("confidence", "medium")),
                source=FindingSource.QWEN,
                finding_category=f.get("finding_category", ""),
                finding_key=f.get("finding_key", ""),
                note_ar=f.get("description_ar", ""),
            ))
        return findings, metadata

    def generate_report(
        self,
        car_model: str,
        year: int,
        mileage: int,
        findings_json: str,
        cost_db_json: str,
        trust_score: int,
    ) -> dict:
        """Call 3: Generate Arabic report text (no images needed)."""
        system = "أنت كاتب تقارير فحص سيارات مصري. رد بـ JSON فقط."
        user_text = build_report_prompt(
            car_model, year, mileage, findings_json, cost_db_json, trust_score,
        )

        raw = self._call(system, user_text)
        return parse_vlm_json_response(raw)
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
pytest carcheck/tests/test_vlm_analyzer.py -v
```

Expected: All 6 tests PASS (these test the prompt building and JSON parsing, not the actual API calls).

- [ ] **Step 6: Commit**

```bash
git add carcheck/pipeline/vlm_analyzer.py carcheck/data/prompts/ carcheck/tests/test_vlm_analyzer.py
git commit -m "feat: VLM analyzer with Arabic prompt templates and 3-call architecture"
```

---

## Task 9: Result Merger

**Files:**
- Create: `carcheck/pipeline/result_merger.py`
- Create: `carcheck/tests/test_result_merger.py`

- [ ] **Step 1: Write failing tests**

Create `carcheck/tests/test_result_merger.py`:

```python
from carcheck.pipeline.result_merger import merge_results
from carcheck.models import (
    Detection, Finding, Severity, ConfidenceLevel, FindingSource,
)


def test_merge_converts_detections_to_findings():
    detections = [
        Detection(
            class_id=0, class_name="dent", class_name_ar="خبطة",
            confidence=0.87, bbox=[100, 200, 300, 400],
            mask_area_pixels=500, image_area_pixels=480000,
        ),
    ]
    findings, all_detections = merge_results(
        detections_per_image=[detections],
        exterior_findings=[],
        interior_findings=[],
    )
    assert len(findings) == 1
    assert findings[0].source == FindingSource.YOLO
    assert findings[0].type == "خبطة"


def test_merge_includes_qwen_findings():
    qwen_finding = Finding(
        type="احتمال إعادة دهان", type_en="Possible repaint",
        location="الرفرف", location_en="Fender",
        severity=Severity.MAJOR, confidence=ConfidenceLevel.LOW,
        source=FindingSource.QWEN,
        finding_category="accident", finding_key="repaint_possible",
    )
    findings, _ = merge_results(
        detections_per_image=[],
        exterior_findings=[qwen_finding],
        interior_findings=[],
    )
    assert len(findings) == 1
    assert findings[0].source == FindingSource.QWEN


def test_merge_combines_all_sources():
    det = Detection(
        class_id=1, class_name="scratch", class_name_ar="خدش",
        confidence=0.9, bbox=[0, 0, 50, 50],
        mask_area_pixels=100, image_area_pixels=480000,
    )
    ext_finding = Finding(
        type="إعادة دهان محتملة", type_en="Possible repaint",
        location="الباب", location_en="Door",
        severity=Severity.MAJOR, confidence=ConfidenceLevel.LOW,
        source=FindingSource.QWEN,
        finding_category="accident", finding_key="repaint_possible",
    )
    int_finding = Finding(
        type="بقع مياه", type_en="Water stains",
        location="المقاعد", location_en="Seats",
        severity=Severity.MAJOR, confidence=ConfidenceLevel.MEDIUM,
        source=FindingSource.QWEN,
        finding_category="flood", finding_key="water_stain",
    )

    findings, all_dets = merge_results(
        detections_per_image=[[det]],
        exterior_findings=[ext_finding],
        interior_findings=[int_finding],
    )
    assert len(findings) == 3
    assert len(all_dets) == 1
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest carcheck/tests/test_result_merger.py -v
```

Expected: FAIL

- [ ] **Step 3: Implement result merger**

Create `carcheck/pipeline/result_merger.py`:

```python
from carcheck.models import Detection, Finding, Severity, ConfidenceLevel, FindingSource
from carcheck.costs.estimator import estimate_repair_cost


def _detection_to_finding(det: Detection, region: str = "cairo") -> Finding:
    """Convert a YOLO detection into a Finding for scoring/reporting."""
    cost = estimate_repair_cost(det.class_name, region=region)

    return Finding(
        type=det.class_name_ar,
        type_en=det.class_name,
        location=f"صورة: {det.image_path}" if det.image_path else "",
        location_en=f"Image: {det.image_path}" if det.image_path else "",
        severity=det.severity,
        confidence=ConfidenceLevel.HIGH,
        source=FindingSource.YOLO,
        cost_min=cost["min"] if cost else None,
        cost_max=cost["max"] if cost else None,
        note_ar=cost["notes_ar"] if cost else "",
    )


def merge_results(
    detections_per_image: list[list[Detection]],
    exterior_findings: list[Finding],
    interior_findings: list[Finding],
    region: str = "cairo",
) -> tuple[list[Finding], list[Detection]]:
    """Merge YOLO detections and Qwen findings into a unified findings list.

    Returns (all_findings, all_detections).
    """
    all_detections: list[Detection] = []
    for dets in detections_per_image:
        all_detections.extend(dets)

    # Convert YOLO detections to findings
    yolo_findings = [_detection_to_finding(d, region) for d in all_detections]

    # Combine all findings
    all_findings = yolo_findings + exterior_findings + interior_findings

    return all_findings, all_detections
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
pytest carcheck/tests/test_result_merger.py -v
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add carcheck/pipeline/result_merger.py carcheck/tests/test_result_merger.py
git commit -m "feat: result merger combines YOLO detections and Qwen findings with cost lookups"
```

---

## Task 10: JSON Output (Arabic-Keyed)

**Files:**
- Create: `carcheck/report/json_output.py`
- Create: `carcheck/tests/test_json_output.py`

- [ ] **Step 1: Write failing tests**

Create `carcheck/tests/test_json_output.py`:

```python
import json
import pytest
from carcheck.report.json_output import inspection_to_arabic_json, inspection_to_english_json
from carcheck.models import (
    InspectionInput, InspectionResult, Finding, Detection,
    TrustScoreResult, SubScore, Severity, ConfidenceLevel, FindingSource,
)


def _make_result() -> InspectionResult:
    return InspectionResult(
        input=InspectionInput(
            photos_dir="/tmp", car_model="Nissan Sunny",
            year=2019, mileage=85000,
        ),
        findings=[
            Finding(
                type="خدش عميق", type_en="Deep scratch",
                location="الباب الخلفي", location_en="Rear door",
                severity=Severity.MAJOR, confidence=ConfidenceLevel.HIGH,
                source=FindingSource.YOLO, cost_min=2000, cost_max=4500,
            ),
        ],
        trust_score=TrustScoreResult(
            total=72, label_ar="فاوض على السعر", label_en="Negotiate Price",
            sub_scores={"body": SubScore(name="body", name_ar="حالة الهيكل", weight=0.30, score=90)},
        ),
        summary_ar="العربية كويسة بشكل عام",
    )


def test_arabic_json_has_arabic_keys():
    result = _make_result()
    output = inspection_to_arabic_json(result)
    parsed = json.loads(output)
    assert "نتيجة_الفحص" in parsed
    assert "درجة_الثقة" in parsed["نتيجة_الفحص"]
    assert parsed["نتيجة_الفحص"]["درجة_الثقة"] == 72


def test_arabic_json_findings_structure():
    result = _make_result()
    output = inspection_to_arabic_json(result)
    parsed = json.loads(output)
    findings = parsed["نتيجة_الفحص"]["النتائج"]
    assert len(findings) == 1
    assert findings[0]["النوع"] == "خدش عميق"
    assert findings[0]["تكلفة_الإصلاح"]["من"] == 2000


def test_english_json_has_english_keys():
    result = _make_result()
    output = inspection_to_english_json(result)
    parsed = json.loads(output)
    assert "inspection_result" in parsed
    assert parsed["inspection_result"]["trust_score"] == 72
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest carcheck/tests/test_json_output.py -v
```

Expected: FAIL

- [ ] **Step 3: Implement JSON output**

Create `carcheck/report/json_output.py`:

```python
import json

from carcheck.models import InspectionResult


def inspection_to_arabic_json(result: InspectionResult) -> str:
    """Serialize inspection result with Arabic keys for user-facing output."""
    findings_ar = []
    for f in result.findings:
        entry = {
            "النوع": f.type,
            "الموقع": f.location,
            "الخطورة": "خطير" if f.severity.value == "major" else "بسيط",
            "مستوى_الثقة": {
                "high": "عالي", "medium": "متوسط", "low": "منخفض"
            }.get(f.confidence.value, f.confidence.value),
            "المصدر": f.source.value,
        }
        if f.cost_min is not None and f.cost_max is not None:
            entry["تكلفة_الإصلاح"] = {"من": f.cost_min, "إلى": f.cost_max, "العملة": "جنيه"}
        else:
            entry["تكلفة_الإصلاح"] = None
        if f.note_ar:
            entry["ملاحظة"] = f.note_ar
        findings_ar.append(entry)

    sub_scores_ar = {}
    if result.trust_score:
        for key, ss in result.trust_score.sub_scores.items():
            sub_scores_ar[ss.name_ar] = {
                "الدرجة": ss.score,
                "الوزن": f"{ss.weight:.0%}",
            }

    output = {
        "نتيجة_الفحص": {
            "درجة_الثقة": result.trust_score.total if result.trust_score else None,
            "التصنيف": result.trust_score.label_ar if result.trust_score else "",
            "السيارة": {
                "الموديل": result.input.car_model,
                "السنة": result.input.year,
                "الكيلومترات_المعلنة": result.input.mileage,
            },
            "النتائج": findings_ar,
            "الدرجات_الفرعية": sub_scores_ar,
            "ملخص": result.summary_ar,
            "التحذيرات": result.warnings,
            "إخلاء_مسؤولية": result.disclaimer_ar,
        }
    }

    return json.dumps(output, ensure_ascii=False, indent=2)


def inspection_to_english_json(result: InspectionResult) -> str:
    """Serialize inspection result with English keys."""
    findings_en = []
    for f in result.findings:
        entry = {
            "type": f.type_en,
            "location": f.location_en,
            "severity": f.severity.value,
            "confidence": f.confidence.value,
            "source": f.source.value,
        }
        if f.cost_min is not None and f.cost_max is not None:
            entry["repair_cost_egp"] = {"min": f.cost_min, "max": f.cost_max}
        else:
            entry["repair_cost_egp"] = None
        findings_en.append(entry)

    output = {
        "inspection_result": {
            "trust_score": result.trust_score.total if result.trust_score else None,
            "label": result.trust_score.label_en if result.trust_score else "",
            "car": {
                "model": result.input.car_model,
                "year": result.input.year,
                "mileage": result.input.mileage,
            },
            "findings": findings_en,
            "summary": result.summary_en,
            "disclaimer": result.disclaimer_en,
        }
    }

    return json.dumps(output, ensure_ascii=False, indent=2)
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
pytest carcheck/tests/test_json_output.py -v
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add carcheck/report/json_output.py carcheck/tests/test_json_output.py
git commit -m "feat: Arabic-keyed and English JSON output serializers"
```

---

## Task 11: PDF Report Builder

**Files:**
- Create: `carcheck/report/templates/report.html`
- Create: `carcheck/report/pdf_builder.py`

- [ ] **Step 1: Create Arabic RTL HTML template**

Create `carcheck/report/templates/report.html`:

```html
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<style>
@import url('https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700&display=swap');

* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: 'Cairo', sans-serif; direction: rtl; color: #1a1a2e; line-height: 1.8; padding: 40px; }

.header { text-align: center; border-bottom: 3px solid #0f3460; padding-bottom: 20px; margin-bottom: 30px; }
.header h1 { font-size: 28px; color: #0f3460; }
.header .subtitle { color: #666; font-size: 14px; }

.score-box { text-align: center; background: #f8f9fa; border-radius: 12px; padding: 24px; margin-bottom: 30px; }
.score-number { font-size: 64px; font-weight: 700; color: {{ score_color }}; }
.score-label { font-size: 22px; font-weight: 600; color: {{ score_color }}; }

.car-info { display: flex; gap: 20px; margin-bottom: 30px; }
.car-info div { flex: 1; background: #f0f0f5; border-radius: 8px; padding: 12px; text-align: center; }
.car-info .label { font-size: 12px; color: #666; }
.car-info .value { font-size: 16px; font-weight: 600; }

.section { margin-bottom: 24px; }
.section h2 { font-size: 18px; color: #0f3460; border-bottom: 1px solid #ddd; padding-bottom: 8px; margin-bottom: 12px; }

.finding { background: #fafafa; border-right: 4px solid {{ finding_color }}; border-radius: 0 8px 8px 0; padding: 14px; margin-bottom: 10px; }
.finding .type { font-weight: 700; font-size: 15px; }
.finding .location { color: #666; font-size: 13px; }
.finding .cost { color: #0f3460; font-weight: 600; }
.finding .confidence { display: inline-block; font-size: 11px; padding: 2px 8px; border-radius: 4px; }
.confidence-high { background: #d4edda; color: #155724; }
.confidence-medium { background: #fff3cd; color: #856404; }
.confidence-low { background: #f8d7da; color: #721c24; }

.summary { background: #e8eaf6; border-radius: 8px; padding: 16px; margin-bottom: 20px; font-size: 15px; }

.disclaimer { text-align: center; color: #999; font-size: 11px; margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee; }

.annotated-photo { max-width: 100%; border-radius: 8px; margin: 8px 0; }
</style>
</head>
<body>

<div class="header">
  <h1>تقرير فحص كارتشيك</h1>
  <div class="subtitle">CarCheck AI Inspection Report</div>
</div>

<div class="score-box">
  <div class="score-number">{{ trust_score }}</div>
  <div class="score-label">{{ score_label_ar }}</div>
</div>

<div class="car-info">
  <div><div class="label">الموديل</div><div class="value">{{ car_model }}</div></div>
  <div><div class="label">السنة</div><div class="value">{{ year }}</div></div>
  <div><div class="label">الكيلومترات</div><div class="value">{{ mileage }}</div></div>
</div>

{% if summary_ar %}
<div class="summary">{{ summary_ar }}</div>
{% endif %}

{% if findings %}
<div class="section">
  <h2>النتائج ({{ findings|length }} مشكلة)</h2>
  {% for f in findings %}
  <div class="finding">
    <div class="type">{{ f.type }}</div>
    <div class="location">📍 {{ f.location }}</div>
    {% if f.cost_min and f.cost_max %}
    <div class="cost">💰 {{ f.cost_min }} - {{ f.cost_max }} جنيه</div>
    {% endif %}
    <span class="confidence confidence-{{ f.confidence.value }}">
      ثقة: {{ {"high": "عالية", "medium": "متوسطة", "low": "منخفضة"}[f.confidence.value] }}
    </span>
    {% if f.note_ar %}
    <div style="color:#666; font-size:13px; margin-top:4px;">{{ f.note_ar }}</div>
    {% endif %}
  </div>
  {% endfor %}
</div>
{% endif %}

{% if warnings %}
<div class="section">
  <h2>تحذيرات</h2>
  {% for w in warnings %}
  <div class="finding" style="border-right-color: #ffc107;">⚠️ {{ w }}</div>
  {% endfor %}
</div>
{% endif %}

<div class="disclaimer">{{ disclaimer_ar }}</div>

</body>
</html>
```

- [ ] **Step 2: Implement PDF builder**

Create `carcheck/report/pdf_builder.py`:

```python
from pathlib import Path
from string import Template

from carcheck.models import InspectionResult

_SCORE_COLORS = {
    "buy": "#28a745",
    "negotiate": "#ffc107",
    "inspect": "#fd7e14",
    "walk": "#dc3545",
}


def _get_score_color(score: int) -> str:
    if score >= 85:
        return _SCORE_COLORS["buy"]
    if score >= 65:
        return _SCORE_COLORS["negotiate"]
    if score >= 40:
        return _SCORE_COLORS["inspect"]
    return _SCORE_COLORS["walk"]


def build_pdf(result: InspectionResult, output_path: Path) -> Path:
    """Generate a PDF report from inspection results using WeasyPrint."""
    from weasyprint import HTML
    from jinja2 import Environment, FileSystemLoader

    templates_dir = Path(__file__).parent / "templates"
    env = Environment(loader=FileSystemLoader(str(templates_dir)))
    template = env.get_template("report.html")

    score = result.trust_score.total if result.trust_score else 0
    score_color = _get_score_color(score)

    html_content = template.render(
        trust_score=score,
        score_label_ar=result.trust_score.label_ar if result.trust_score else "",
        score_color=score_color,
        finding_color="#0f3460",
        car_model=result.input.car_model,
        year=result.input.year,
        mileage=result.input.mileage,
        summary_ar=result.summary_ar,
        findings=result.findings,
        warnings=result.warnings,
        disclaimer_ar=result.disclaimer_ar,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    HTML(string=html_content).write_pdf(str(output_path))
    return output_path
```

Note: This adds `jinja2` as a dependency. Update `pyproject.toml`:

```toml
dependencies = [
    ...
    "jinja2>=3.1",
]
```

- [ ] **Step 3: Commit**

```bash
git add carcheck/report/templates/report.html carcheck/report/pdf_builder.py pyproject.toml
git commit -m "feat: Arabic RTL PDF report builder with Jinja2 template and WeasyPrint"
```

---

## Task 12: Report Generator (Orchestrator)

**Files:**
- Create: `carcheck/report/generator.py`

- [ ] **Step 1: Implement report generator**

Create `carcheck/report/generator.py`:

```python
from pathlib import Path

from carcheck.models import InspectionResult
from carcheck.report.json_output import inspection_to_arabic_json, inspection_to_english_json
from carcheck.report.pdf_builder import build_pdf


def generate_report(
    result: InspectionResult,
    output_json: Path | None = None,
    output_pdf: Path | None = None,
    lang: str = "ar",
) -> dict[str, Path]:
    """Generate output files from an inspection result.

    Returns dict of output type -> file path for files that were created.
    """
    outputs: dict[str, Path] = {}

    if output_json:
        output_json.parent.mkdir(parents=True, exist_ok=True)
        if lang == "ar":
            content = inspection_to_arabic_json(result)
        else:
            content = inspection_to_english_json(result)
        output_json.write_text(content, encoding="utf-8")
        outputs["json"] = output_json

    if output_pdf:
        build_pdf(result, output_pdf)
        outputs["pdf"] = output_pdf

    return outputs
```

- [ ] **Step 2: Commit**

```bash
git add carcheck/report/generator.py
git commit -m "feat: report generator orchestrates JSON and PDF output"
```

---

## Task 13: CLI Entry Point

**Files:**
- Create: `carcheck/cli.py`

- [ ] **Step 1: Implement CLI with Typer**

Create `carcheck/cli.py`:

```python
from pathlib import Path
from typing import Optional

import typer

app = typer.Typer(name="carcheck", help="CarCheck — AI-powered car inspection for Egypt")


@app.command()
def inspect(
    photos_dir: Path = typer.Argument(..., help="Directory containing car photos"),
    car_model: str = typer.Option(..., "--car-model", "-m", help="Car model (e.g., 'Nissan Sunny')"),
    year: int = typer.Option(..., "--year", "-y", help="Car manufacturing year"),
    mileage: int = typer.Option(..., "--mileage", "-k", help="Stated mileage in km"),
    output_json: Optional[Path] = typer.Option(None, "--output-json", "-j", help="Path for JSON report"),
    output_pdf: Optional[Path] = typer.Option(None, "--output-pdf", "-p", help="Path for PDF report"),
    lang: str = typer.Option("ar", "--lang", "-l", help="Output language: ar (default) or en"),
    region: str = typer.Option("cairo", "--region", "-r", help="Region for cost estimates: cairo, alexandria"),
) -> None:
    """Run a full AI inspection on car photos."""
    import json
    from rich.console import Console
    from rich.panel import Panel

    from carcheck.config import settings
    from carcheck.models import InspectionInput, InspectionResult
    from carcheck.pipeline.preprocessor import validate_photos_dir, preprocess_image
    from carcheck.pipeline.yolo_detector import YOLODetector
    from carcheck.pipeline.image_annotator import annotate_image
    from carcheck.pipeline.vlm_analyzer import VLMAnalyzer
    from carcheck.pipeline.result_merger import merge_results
    from carcheck.scoring.trust_score import calculate_trust_score
    from carcheck.report.generator import generate_report

    console = Console()

    # Validate input
    console.print("[bold]🔍 CarCheck AI Inspection[/bold]\n")
    image_paths = validate_photos_dir(photos_dir)
    console.print(f"📸 Found {len(image_paths)} photos in {photos_dir}")

    inspection_input = InspectionInput(
        photos_dir=str(photos_dir),
        car_model=car_model,
        year=year,
        mileage=mileage,
        lang=lang,
        region=region,
    )

    # Step 1: Preprocess
    console.print("⚙️  Preprocessing images...")
    processed_dir = photos_dir / "_processed"
    processed_paths = []
    for p in image_paths:
        processed_paths.append(preprocess_image(p, processed_dir))

    # Step 2: YOLO detection
    console.print("🔎 Running YOLO11 damage detection...")
    detector = YOLODetector()
    detections_per_image = detector.detect(processed_paths)
    total_dets = sum(len(d) for d in detections_per_image)
    console.print(f"   Found {total_dets} damage instances across {len(image_paths)} photos")

    # Step 3: Annotate photos
    console.print("🖊️  Annotating photos with detections...")
    annotated_dir = photos_dir / "_annotated"
    annotated_paths = []
    for path, dets in zip(processed_paths, detections_per_image):
        annotated_paths.append(annotate_image(path, dets, annotated_dir))

    # Step 4: VLM analysis
    console.print("🧠 Running Qwen3.5 vision analysis...")
    vlm = VLMAnalyzer()

    # Split photos for exterior (first 8) and interior (rest)
    exterior_photos = annotated_paths[:8] if len(annotated_paths) >= 8 else annotated_paths
    interior_photos = annotated_paths[8:] if len(annotated_paths) > 8 else []

    dets_json = json.dumps(
        [d.model_dump() for dets in detections_per_image for d in dets],
        ensure_ascii=False,
    )

    console.print("   Call 1/3: Exterior analysis...")
    exterior_findings = vlm.analyze_exterior(
        exterior_photos, car_model, year, mileage, dets_json,
    )

    console.print("   Call 2/3: Interior & documentation...")
    interior_findings, metadata = vlm.analyze_interior(
        interior_photos, car_model, year, mileage,
    ) if interior_photos else ([], {})

    # Step 5: Merge results
    console.print("📊 Merging results...")
    all_findings, all_detections = merge_results(
        detections_per_image, exterior_findings, interior_findings, region,
    )

    # Step 6: Calculate trust score
    trust_score = calculate_trust_score(all_detections, all_findings)

    # Step 7: Generate report text
    console.print("   Call 3/3: Generating Arabic report...")
    cost_db_text = settings.cost_db_path.read_text(encoding="utf-8")
    report_data = vlm.generate_report(
        car_model, year, mileage,
        json.dumps([f.model_dump() for f in all_findings], ensure_ascii=False),
        cost_db_text,
        trust_score.total,
    )

    # Build final result
    result = InspectionResult(
        input=inspection_input,
        detections=all_detections,
        findings=all_findings,
        trust_score=trust_score,
        summary_ar=report_data.get("summary_ar", ""),
        warnings=report_data.get("warnings", []),
    )

    # Add low-confidence warning
    for f in all_findings:
        if f.confidence.value == "low" and f.finding_category == "accident":
            result.warnings.append("ننصح بفحص ميكانيكي للتأكد من حالة الدهان")
            break

    # Step 8: Output
    if not output_json and not output_pdf:
        output_json = photos_dir / "report.json"

    outputs = generate_report(result, output_json, output_pdf, lang)

    # Display summary
    score_color = "green" if trust_score.total >= 85 else "yellow" if trust_score.total >= 65 else "red"
    console.print(Panel(
        f"[bold {score_color}]{trust_score.total}/100 — {trust_score.label_ar}[/bold {score_color}]",
        title="درجة الثقة",
        expand=False,
    ))
    console.print(f"\n📋 Findings: {len(all_findings)}")
    for f in all_findings:
        icon = "🔴" if f.severity.value == "major" else "🟡"
        console.print(f"   {icon} {f.type} — {f.location}")

    for fmt, path in outputs.items():
        console.print(f"\n✅ {fmt.upper()} report saved to: {path}")


@app.command()
def detect(
    photos_dir: Path = typer.Argument(..., help="Directory containing car photos"),
) -> None:
    """Run YOLO detection only (no VLM analysis). Quick test mode."""
    from rich.console import Console
    from rich.table import Table

    from carcheck.pipeline.preprocessor import validate_photos_dir, preprocess_image
    from carcheck.pipeline.yolo_detector import YOLODetector
    from carcheck.pipeline.image_annotator import annotate_image

    console = Console()
    console.print("[bold]🔎 CarCheck — YOLO Detection Only[/bold]\n")

    image_paths = validate_photos_dir(photos_dir)
    console.print(f"📸 Found {len(image_paths)} photos")

    processed_dir = photos_dir / "_processed"
    processed = [preprocess_image(p, processed_dir) for p in image_paths]

    detector = YOLODetector()
    results = detector.detect(processed)

    annotated_dir = photos_dir / "_annotated"
    for path, dets in zip(processed, results):
        annotate_image(path, dets, annotated_dir)

    table = Table(title="Detection Results")
    table.add_column("Image", style="cyan")
    table.add_column("Class", style="bold")
    table.add_column("Arabic", style="bold")
    table.add_column("Confidence")
    table.add_column("Severity")

    for path, dets in zip(image_paths, results):
        for d in dets:
            sev_color = "red" if d.severity.value == "major" else "yellow"
            table.add_row(
                path.name, d.class_name, d.class_name_ar,
                f"{d.confidence:.0%}",
                f"[{sev_color}]{d.severity.value}[/{sev_color}]",
            )

    console.print(table)
    console.print(f"\n🖊️  Annotated photos saved to: {annotated_dir}")


if __name__ == "__main__":
    app()
```

Note: This uses `rich` for terminal output. Add to `pyproject.toml`:

```toml
dependencies = [
    ...
    "rich>=13.0",
]
```

- [ ] **Step 2: Commit**

```bash
git add carcheck/cli.py pyproject.toml
git commit -m "feat: Typer CLI with inspect and detect commands"
```

---

## Task 14: VPS Setup & Model Download

**Files:**
- Create: `scripts/setup_vps.sh`

- [ ] **Step 1: Create VPS setup script**

Create `scripts/setup_vps.sh`:

```bash
#!/bin/bash
set -euo pipefail

echo "=== CarCheck VPS Setup ==="

# 1. Install vLLM
echo "📦 Installing vLLM..."
pip install vllm

# 2. Download YOLO11 weights from HuggingFace
echo "📥 Downloading YOLO11 car damage weights..."
MODELS_DIR="carcheck/data/models"
mkdir -p "$MODELS_DIR"

# Download pre-trained CarDD weights
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

# Rename to expected filename
mv "$MODELS_DIR/best.pt" "$MODELS_DIR/yolo11x-seg.pt" 2>/dev/null || true

echo "✅ YOLO weights ready at $MODELS_DIR/yolo11x-seg.pt"

# 3. Start vLLM server
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
echo "=== Then in another terminal, run carcheck: ==="
echo ""
echo "carcheck inspect ./test_photos/ --car-model 'Nissan Sunny' --year 2019 --mileage 85000"
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x scripts/setup_vps.sh
git add scripts/setup_vps.sh
git commit -m "feat: VPS setup script for vLLM and YOLO model download"
```

---

## Task 15: End-to-End Integration Test

**Files:**
- Create: `carcheck/tests/test_integration.py`

This test validates the full pipeline minus the actual AI models (mocked).

- [ ] **Step 1: Write integration test**

Create `carcheck/tests/test_integration.py`:

```python
"""End-to-end integration test with mocked AI models."""
import json
import pytest
from pathlib import Path
from unittest.mock import patch, MagicMock
from PIL import Image

from carcheck.models import InspectionInput, Detection
from carcheck.pipeline.preprocessor import validate_photos_dir, preprocess_image
from carcheck.pipeline.image_annotator import annotate_image
from carcheck.pipeline.result_merger import merge_results
from carcheck.scoring.trust_score import calculate_trust_score
from carcheck.report.json_output import inspection_to_arabic_json
from carcheck.models import (
    InspectionResult, Finding, Severity, ConfidenceLevel, FindingSource,
)


@pytest.fixture
def inspection_photos(tmp_path: Path) -> Path:
    """Create a directory with 5 synthetic test photos."""
    photos = tmp_path / "car_photos"
    photos.mkdir()
    for i in range(5):
        img = Image.new("RGB", (1024, 768), color=(120 + i * 20, 100, 80))
        img.save(photos / f"photo_{i:02d}.jpg", "JPEG")
    return photos


def _fake_detections() -> list[list[Detection]]:
    """Simulate YOLO finding 2 dents and a scratch across 5 images."""
    dets_img0 = [
        Detection(
            class_id=0, class_name="dent", class_name_ar="خبطة",
            confidence=0.85, bbox=[100, 200, 250, 350],
            mask_area_pixels=800, image_area_pixels=786432,  # minor
        ),
    ]
    dets_img1 = [
        Detection(
            class_id=0, class_name="dent", class_name_ar="خبطة",
            confidence=0.72, bbox=[300, 100, 500, 300],
            mask_area_pixels=25000, image_area_pixels=786432,  # major: 3.2%
        ),
        Detection(
            class_id=1, class_name="scratch", class_name_ar="خدش",
            confidence=0.91, bbox=[50, 400, 200, 450],
            mask_area_pixels=500, image_area_pixels=786432,  # minor
        ),
    ]
    return [dets_img0, dets_img1, [], [], []]


def test_full_pipeline_mock(inspection_photos: Path, tmp_path: Path):
    """Test the full pipeline with fake YOLO detections and no VLM."""
    # 1. Preprocess
    image_paths = validate_photos_dir(inspection_photos)
    assert len(image_paths) == 5

    processed_dir = tmp_path / "processed"
    processed = [preprocess_image(p, processed_dir) for p in image_paths]
    assert all(p.exists() for p in processed)

    # 2. Fake YOLO detections
    detections_per_image = _fake_detections()

    # 3. Annotate
    annotated_dir = tmp_path / "annotated"
    for path, dets in zip(processed, detections_per_image):
        annotate_image(path, dets, annotated_dir)

    # 4. Fake Qwen findings (simulating what VLM would return)
    exterior_findings = [
        Finding(
            type="احتمال إعادة دهان", type_en="Possible repaint",
            location="الرفرف الأمامي اليمين", location_en="Front right fender",
            severity=Severity.MAJOR, confidence=ConfidenceLevel.LOW,
            source=FindingSource.QWEN,
            finding_category="accident", finding_key="repaint_possible",
        ),
    ]
    interior_findings = []

    # 5. Merge
    all_findings, all_dets = merge_results(
        detections_per_image, exterior_findings, interior_findings,
    )
    # 3 YOLO findings + 1 Qwen = 4 total
    assert len(all_findings) == 4
    assert len(all_dets) == 3

    # 6. Score
    trust_score = calculate_trust_score(all_dets, all_findings)
    assert 0 <= trust_score.total <= 100
    assert trust_score.label_ar != ""

    # 7. Build result and generate JSON
    result = InspectionResult(
        input=InspectionInput(
            photos_dir=str(inspection_photos),
            car_model="Nissan Sunny",
            year=2019,
            mileage=85000,
        ),
        detections=all_dets,
        findings=all_findings,
        trust_score=trust_score,
        summary_ar="العربية فيها شوية خبطات وخدش بسيط واحتمال الرفرف متدهن",
    )

    json_output = inspection_to_arabic_json(result)
    parsed = json.loads(json_output)

    assert "نتيجة_الفحص" in parsed
    assert parsed["نتيجة_الفحص"]["درجة_الثقة"] == trust_score.total
    assert len(parsed["نتيجة_الفحص"]["النتائج"]) == 4
```

- [ ] **Step 2: Run integration test**

```bash
pytest carcheck/tests/test_integration.py -v
```

Expected: PASS — full pipeline works with mocked AI.

- [ ] **Step 3: Run all tests**

```bash
pytest carcheck/tests/ -v --tb=short
```

Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
git add carcheck/tests/test_integration.py
git commit -m "feat: end-to-end integration test with mocked AI models"
```

---

## Task 16: README & Final Polish

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create README**

Create `README.md`:

```markdown
# CarCheck — فحص سيارات بالذكاء الاصطناعي

AI-powered used car inspection for the Egyptian market.

## Setup

```bash
# Clone and install
git clone <repo-url>
cd CheKar
python -m venv .venv
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
```

- [ ] **Step 2: Run final test suite**

```bash
pytest carcheck/tests/ -v --tb=short
```

Expected: All tests PASS.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: README with setup and usage instructions"
```
