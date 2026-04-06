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


class TrafficLight(str, Enum):
    GREEN = "green"
    YELLOW = "yellow"
    RED = "red"
    NOT_ASSESSED = "not_assessed"


class CategoryResult(BaseModel):
    """Traffic light result for one assessment category."""
    name: str
    name_ar: str
    light: TrafficLight
    findings: list[Finding] = []


GRADE_INFO = {
    "A": {"ar": "ممتاز", "color": "#16A34A", "rec_ar": "العربية شكلها كويس من برا. اعمل كشف ميكانيكي للاطمئنان وخلاص."},
    "B": {"ar": "جيد جداً", "color": "#EAB308", "rec_ar": "فيه حاجات بسيطة بس مفيش حاجة تقلق. اعمل كشف ميكانيكي قبل ما تشتري."},
    "C": {"ar": "مقبول", "color": "#F97316", "rec_ar": "فيه مشاكل محتاجة تتصلح. اتفاوض على السعر واعمل كشف ميكانيكي."},
    "D": {"ar": "يحتاج فحص", "color": "#DC2626", "rec_ar": "فيه مشاكل كبيرة. متشتريش من غير كشف ميكانيكي كامل."},
    "F": {"ar": "ابعد عنها", "color": "#7F1D1D", "rec_ar": "علامات خطر كتير. الأحسن تدور على عربية تانية."},
}

UNASSESSED_AREAS_AR = [
    "الحالة الميكانيكية (المحرك، الفتيس، الفرامل) — محتاج كشف ميكانيكي",
    "الكهربا والحساسات — محتاج جهاز تشخيص",
    "أسفل العربية — محتاج رافعة",
    "دقة العداد — مش مضمونة من الصور",
]


class GradeResult(BaseModel):
    """Complete grading result — replaces TrustScoreResult."""
    grade: str
    grade_ar: str
    grade_color: str
    recommendation_ar: str
    categories: dict[str, CategoryResult]
    unassessed_areas_ar: list[str] = UNASSESSED_AREAS_AR
    has_critical_finding: bool = False


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
    grade_result: GradeResult | None = None
    summary_ar: str = ""
    summary_en: str = ""
    disclaimer_ar: str = "التقرير ده تقييم بالذكاء الاصطناعي بناءً على الصور — مش بديل عن الفحص الميكانيكي"
    disclaimer_en: str = "This is an AI assessment based on photos — not a substitute for mechanical inspection"
    warnings: list[str] = []
