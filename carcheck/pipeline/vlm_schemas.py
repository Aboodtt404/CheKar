"""JSON schemas for vLLM guided_json structured output.

Each schema enforces valid JSON with enum-constrained fields.
Used with response_format={"type": "json_schema", "json_schema": {...}}
"""

VALIDATION_SCHEMA = {
    "type": "object",
    "properties": {
        "is_car": {"type": "boolean"},
        "message_ar": {"type": "string"},
    },
    "required": ["is_car", "message_ar"],
    "additionalProperties": False,
}

DETECTION_CLASSIFICATION_SCHEMA = {
    "type": "object",
    "properties": {
        "classified_detections": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "region_id": {"type": "integer"},
                    "class_en": {
                        "type": "string",
                        "enum": [
                            "dent", "scratch", "crack", "glass_shatter",
                            "lamp_broken", "tire_flat",
                            "no_damage", "not_car", "false_positive",
                        ],
                    },
                    "class_ar": {"type": "string"},
                    "severity": {
                        "type": "string",
                        "enum": ["minor", "major"],
                    },
                    "confidence": {
                        "type": "string",
                        "enum": ["high", "medium", "low"],
                    },
                    "description_ar": {"type": "string"},
                },
                "required": ["region_id", "class_en", "class_ar", "severity", "confidence", "description_ar"],
                "additionalProperties": False,
            },
        },
    },
    "required": ["classified_detections"],
    "additionalProperties": False,
}

FULL_ASSESSMENT_SCHEMA = {
    "type": "object",
    "properties": {
        "additional_findings": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "type": {"type": "string"},
                    "type_en": {"type": "string"},
                    "location": {"type": "string"},
                    "location_en": {"type": "string"},
                    "severity": {
                        "type": "string",
                        "enum": ["minor", "major"],
                    },
                    "confidence": {
                        "type": "string",
                        "enum": ["high", "medium", "low"],
                    },
                    "finding_category": {
                        "type": "string",
                        "enum": ["accident", "body"],
                    },
                    "finding_key": {
                        "type": "string",
                        "enum": [
                            "repaint_possible", "repaint_likely",
                            "panel_misalignment", "adjacent_panels_damaged",
                        ],
                    },
                    "description_ar": {"type": "string"},
                },
                "required": [
                    "type", "type_en", "location", "location_en",
                    "severity", "confidence", "finding_category",
                    "finding_key", "description_ar",
                ],
                "additionalProperties": False,
            },
        },
        "repaint_detected": {"type": "boolean"},
        "panel_misalignment_detected": {"type": "boolean"},
        "overall_exterior_note_ar": {"type": "string"},
    },
    "required": [
        "additional_findings", "repaint_detected",
        "panel_misalignment_detected", "overall_exterior_note_ar",
    ],
    "additionalProperties": False,
}

INTERIOR_ANALYSIS_SCHEMA = {
    "type": "object",
    "properties": {
        "odometer_reading": {"type": "integer"},
        "odometer_matches_wear": {"type": "boolean"},
        "year_model_verified": {"type": "boolean"},
        "interior_findings": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "type": {"type": "string"},
                    "type_en": {"type": "string"},
                    "location": {"type": "string"},
                    "location_en": {"type": "string"},
                    "severity": {
                        "type": "string",
                        "enum": ["minor", "major"],
                    },
                    "confidence": {
                        "type": "string",
                        "enum": ["high", "medium", "low"],
                    },
                    "finding_category": {
                        "type": "string",
                        "enum": ["flood", "mechanical", "docs"],
                    },
                    "finding_key": {
                        "type": "string",
                        "enum": [
                            "water_stain", "unusual_corrosion", "mud_residue",
                            "multiple_indicators", "oil_leak", "belt_deterioration",
                            "engine_corrosion", "battery_corrosion",
                            "odometer_mismatch", "year_model_failed", "vin_unreadable",
                        ],
                    },
                    "description_ar": {"type": "string"},
                },
                "required": [
                    "type", "type_en", "location", "location_en",
                    "severity", "confidence", "finding_category",
                    "finding_key", "description_ar",
                ],
                "additionalProperties": False,
            },
        },
    },
    "required": ["odometer_reading", "odometer_matches_wear", "year_model_verified", "interior_findings"],
    "additionalProperties": False,
}

REPORT_GENERATION_SCHEMA = {
    "type": "object",
    "properties": {
        "summary_ar": {"type": "string"},
        "findings_with_costs": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "type": {"type": "string"},
                    "description_ar": {"type": "string"},
                    "cost_min": {"type": "integer"},
                    "cost_max": {"type": "integer"},
                    "advice_ar": {"type": "string"},
                },
                "required": ["type", "description_ar", "cost_min", "cost_max", "advice_ar"],
                "additionalProperties": False,
            },
        },
        "total_estimated_repair_cost": {
            "type": "object",
            "properties": {
                "min": {"type": "integer"},
                "max": {"type": "integer"},
            },
            "required": ["min", "max"],
            "additionalProperties": False,
        },
        "final_advice_ar": {"type": "string"},
    },
    "required": ["summary_ar", "findings_with_costs", "total_estimated_repair_cost", "final_advice_ar"],
    "additionalProperties": False,
}


def build_response_format(name: str, schema: dict) -> dict:
    """Wrap a JSON schema into OpenAI-compatible response_format."""
    return {
        "type": "json_schema",
        "json_schema": {
            "name": name,
            "schema": schema,
            "strict": True,
        },
    }
