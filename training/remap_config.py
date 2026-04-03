"""Class remapping configuration for merging datasets into CarDD 6-class standard."""

CARDD_CLASSES = {
    0: "dent",
    1: "scratch",
    2: "crack",
    3: "glass_shatter",
    4: "lamp_broken",
    5: "tire_flat",
}

DATASET_REMAPS: dict[str, dict[int, int | None]] = {
    "dammage-detection-in-car": {
        0: None, 1: 0, 2: 0, 3: None, 4: 0, 5: 0, 6: 3, 7: None,
        8: 4, 9: None, 10: 1, 11: 3, 12: None, 13: None, 14: 0, 15: 0,
        16: 0, 17: 0, 18: None, 19: 4, 20: None, 21: 4, 22: 0, 23: None, 24: 0,
    },
    "car-damaged-severity-detection": {
        0: 2, 1: 5, 2: 2, 3: 0, 4: 1, 5: 0, 6: 1, 7: 0, 8: 2, 9: 1,
    },
    "car-damage-4-classes": {
        0: 2, 1: 0, 2: 3, 3: 1,
    },
}

DROP_CLASS_IDS: dict[str, set[int]] = {
    "dammage-detection-in-car": {0, 3, 7, 9, 12, 13, 18, 20, 23},
}

LIGHT_PART_CLASSES = {
    "front_left_light", "front_right_light",
    "back_left_light", "back_right_light",
    "front_light", "back_light",
}

GLASS_PART_CLASSES = {"front_glass", "back_glass"}


def remap_class_id(dataset_name: str, original_id: int) -> int | None:
    remap = DATASET_REMAPS.get(dataset_name)
    if remap is None:
        return None
    return remap.get(original_id)
