import pytest

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


def test_inspection_result_defaults():
    inp = InspectionInput(
        photos_dir="/tmp/photos",
        car_model="Toyota Corolla",
        year=2020,
        mileage=60000,
    )
    result = InspectionResult(input=inp)
    assert result.detections == []
    assert result.findings == []
    assert result.trust_score is None
    assert "ذكاء الاصطناعي" in result.disclaimer_ar
