import pytest
from carcheck.models import Detection, Finding, Severity, ConfidenceLevel, FindingSource, TrafficLight
from carcheck.scoring.grading import calculate_grade, determine_light


def _finding(type_en="scratch", severity="minor", confidence="high", source="Qwen", category="", key=""):
    return Finding(
        type="test", type_en=type_en, location="test", location_en="test",
        severity=Severity(severity), confidence=ConfidenceLevel(confidence),
        source=FindingSource(source), finding_category=category, finding_key=key,
    )


def test_no_findings_grade_a():
    result = calculate_grade(detections=[], findings=[], mode="quick")
    assert result.grade == "A"
    assert result.grade_ar == "ممتاز"


def test_minor_scratch_grade_b():
    findings = [_finding(type_en="scratch", severity="minor", confidence="high")]
    result = calculate_grade(detections=[], findings=findings, mode="quick")
    assert result.grade == "B"
    assert result.categories["paint"].light == TrafficLight.YELLOW


def test_major_dent_grade_c():
    findings = [_finding(type_en="dent", severity="major", confidence="high")]
    result = calculate_grade(detections=[], findings=findings, mode="quick")
    assert result.grade == "C"
    assert result.categories["body"].light == TrafficLight.RED


def test_three_minor_scratches_red():
    findings = [_finding(type_en="scratch", severity="minor", confidence="high") for _ in range(3)]
    result = calculate_grade(detections=[], findings=findings, mode="quick")
    assert result.categories["paint"].light == TrafficLight.RED
    assert result.grade == "C"


def test_accident_signs_red_grade_d():
    findings = [_finding(category="accident_signs", key="repaint_likely", severity="major", confidence="medium")]
    result = calculate_grade(detections=[], findings=findings, mode="quick")
    assert result.categories["accident_signs"].light == TrafficLight.RED
    assert result.grade == "D"


def test_accident_signs_low_confidence_yellow():
    findings = [_finding(category="accident_signs", key="repaint_possible", severity="minor", confidence="low")]
    result = calculate_grade(detections=[], findings=findings, mode="quick")
    assert result.categories["accident_signs"].light == TrafficLight.YELLOW
    assert result.grade == "B"


def test_critical_finding_grade_f():
    findings = [_finding(category="documents", key="odometer_mismatch", severity="major", confidence="high")]
    result = calculate_grade(detections=[], findings=findings, mode="full")
    assert result.grade == "F"
    assert result.has_critical_finding is True


def test_quick_mode_interior_not_assessed():
    result = calculate_grade(detections=[], findings=[], mode="quick")
    assert result.categories["interior"].light == TrafficLight.NOT_ASSESSED
    assert result.categories["documents"].light == TrafficLight.NOT_ASSESSED


def test_full_mode_interior_assessed():
    result = calculate_grade(detections=[], findings=[], mode="full")
    assert result.categories["interior"].light == TrafficLight.GREEN
    assert result.categories["documents"].light == TrafficLight.GREEN


def test_two_reds_grade_d():
    findings = [
        _finding(type_en="dent", severity="major", confidence="high"),
        _finding(type_en="glass_shatter", severity="major", confidence="high"),
    ]
    result = calculate_grade(detections=[], findings=findings, mode="quick")
    assert result.grade == "D"


def test_unassessed_areas_always_present():
    result = calculate_grade(detections=[], findings=[], mode="quick")
    assert len(result.unassessed_areas_ar) == 4


def test_recommendation_present():
    result = calculate_grade(detections=[], findings=[], mode="quick")
    assert "كشف ميكانيكي" in result.recommendation_ar
