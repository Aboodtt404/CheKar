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
