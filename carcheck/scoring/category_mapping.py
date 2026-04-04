"""Maps findings to assessment categories for traffic light calculation."""

from carcheck.models import Finding

CATEGORIES = {
    "paint": "حالة الطلاء",
    "body": "حالة الهيكل",
    "glass_lights": "الزجاج والإضاءة",
    "interior": "الداخلية",
    "accident_signs": "إشارات حوادث",
    "documents": "المستندات",
}

YOLO_CLASS_TO_CATEGORY = {
    "scratch": ["paint"],
    "dent": ["body"],
    "crack": ["glass_lights"],
    "glass_shatter": ["glass_lights"],
    "lamp_broken": ["glass_lights"],
    "tire_flat": ["body"],
}

FINDING_KEY_TO_CATEGORY = {
    "repaint_possible": ["paint", "accident_signs"],
    "repaint_likely": ["paint", "accident_signs"],
    "panel_misalignment": ["body", "accident_signs"],
    "adjacent_panels_damaged": ["body", "accident_signs"],
    "water_stain": ["interior"],
    "unusual_corrosion": ["interior"],
    "mud_residue": ["interior"],
    "multiple_indicators": ["interior"],
    "oil_leak": ["body"],
    "belt_deterioration": ["body"],
    "engine_corrosion": ["body"],
    "battery_corrosion": ["body"],
    "odometer_mismatch": ["documents"],
    "year_model_failed": ["documents"],
    "vin_unreadable": ["documents"],
}

CRITICAL_FINDING_KEYS = {"odometer_mismatch", "year_model_failed"}


def categorize_finding(finding: Finding) -> list[str]:
    """Return list of category names this finding belongs to."""
    if finding.finding_key and finding.finding_key in FINDING_KEY_TO_CATEGORY:
        return FINDING_KEY_TO_CATEGORY[finding.finding_key]
    elif finding.finding_category and finding.finding_category in CATEGORIES:
        return [finding.finding_category]
    elif finding.type_en in YOLO_CLASS_TO_CATEGORY:
        return YOLO_CLASS_TO_CATEGORY[finding.type_en]
    else:
        return ["paint"]
