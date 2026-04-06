import pytest
from carcheck.scoring.trust_score import calculate_trust_score, get_score_label
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
            finding_category="accident", finding_key="repaint_possible",
        ),
    ]
    result = calculate_trust_score(detections=detections, findings=findings)
    assert result.total < 95  # noticeably lower than 100


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
    assert get_score_label(95) == ("اشتري بثقة", "Buy Confidently")
    assert get_score_label(75) == ("فاوض على السعر", "Negotiate Price")
    assert get_score_label(50) == ("اعمل فحص ميكانيكي", "Get Mechanic Inspection")
    assert get_score_label(20) == ("ابعد عن العربية دي", "Walk Away")
