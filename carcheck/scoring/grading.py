"""Letter grade + traffic light scoring system."""

from carcheck.models import (
    Detection, Finding, Severity, ConfidenceLevel,
    TrafficLight, CategoryResult, GradeResult, GRADE_INFO, UNASSESSED_AREAS_AR,
)
from carcheck.scoring.category_mapping import (
    CATEGORIES, CRITICAL_FINDING_KEYS, categorize_finding,
)


def determine_light(findings: list[Finding], is_accident_signs: bool = False) -> TrafficLight:
    """Determine traffic light color for a category based on its findings."""
    if not findings:
        return TrafficLight.GREEN

    major_confirmed = [f for f in findings if f.severity == Severity.MAJOR and f.confidence in (ConfidenceLevel.HIGH, ConfidenceLevel.MEDIUM)]
    minor_confirmed = [f for f in findings if f.severity == Severity.MINOR and f.confidence in (ConfidenceLevel.HIGH, ConfidenceLevel.MEDIUM)]
    low_confidence = [f for f in findings if f.confidence == ConfidenceLevel.LOW]

    if major_confirmed:
        return TrafficLight.RED
    if len(minor_confirmed) >= 3:
        return TrafficLight.RED
    if is_accident_signs and (minor_confirmed or low_confidence):
        return TrafficLight.YELLOW
    if minor_confirmed or low_confidence:
        return TrafficLight.YELLOW
    return TrafficLight.GREEN


def _grade_from_lights(categories: dict[str, CategoryResult], has_critical: bool) -> str:
    if has_critical:
        return "F"
    assessed = {name: cat for name, cat in categories.items() if cat.light != TrafficLight.NOT_ASSESSED}
    reds = [name for name, cat in assessed.items() if cat.light == TrafficLight.RED]
    yellows = [name for name, cat in assessed.items() if cat.light == TrafficLight.YELLOW]
    accident_red = "accident_signs" in reds

    # Paint red driven by accident indicators is not an independent red — exclude it
    # when checking if accident_signs has additional unrelated red categories.
    independent_reds = [n for n in reds if n not in ("accident_signs", "paint")]
    if accident_red and independent_reds:
        return "F"
    if len(reds) >= 2 or accident_red:
        return "D"
    if len(reds) == 1:
        return "C"
    if yellows:
        return "B"
    return "A"


def calculate_grade(detections: list[Detection], findings: list[Finding], mode: str = "quick") -> GradeResult:
    """Calculate letter grade + traffic lights from detections and findings."""
    category_findings: dict[str, list[Finding]] = {name: [] for name in CATEGORIES}

    has_critical = False
    for finding in findings:
        cats = categorize_finding(finding)
        for cat in cats:
            if cat in category_findings:
                category_findings[cat].append(finding)
        if finding.finding_key in CRITICAL_FINDING_KEYS:
            has_critical = True

    categories: dict[str, CategoryResult] = {}
    for name, name_ar in CATEGORIES.items():
        if mode == "quick" and name in ("interior", "documents"):
            categories[name] = CategoryResult(name=name, name_ar=name_ar, light=TrafficLight.NOT_ASSESSED, findings=[])
        else:
            light = determine_light(category_findings[name], is_accident_signs=(name == "accident_signs"))
            categories[name] = CategoryResult(name=name, name_ar=name_ar, light=light, findings=category_findings[name])

    grade = _grade_from_lights(categories, has_critical)
    info = GRADE_INFO[grade]

    return GradeResult(
        grade=grade, grade_ar=info["ar"], grade_color=info["color"],
        recommendation_ar=info["rec_ar"], categories=categories,
        unassessed_areas_ar=list(UNASSESSED_AREAS_AR), has_critical_finding=has_critical,
    )
