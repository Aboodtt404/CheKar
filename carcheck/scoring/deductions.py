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
