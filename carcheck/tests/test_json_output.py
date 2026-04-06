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
