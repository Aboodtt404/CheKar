from training.remap_config import CARDD_CLASSES, DATASET_REMAPS, DROP_CLASS_IDS, remap_class_id

def test_cardd_classes():
    assert CARDD_CLASSES == {0: "dent", 1: "scratch", 2: "crack", 3: "glass_shatter", 4: "lamp_broken", 5: "tire_flat"}

def test_remap_dataset1_dent():
    assert remap_class_id("dammage-detection-in-car", 1) == 0

def test_remap_dataset1_lamp_broken():
    assert remap_class_id("dammage-detection-in-car", 8) == 4

def test_remap_dataset1_glass_shatter():
    assert remap_class_id("dammage-detection-in-car", 6) == 3

def test_remap_dataset1_drop_no_damage():
    assert remap_class_id("dammage-detection-in-car", 0) is None

def test_remap_dataset1_drop_headlight_no_damage():
    assert remap_class_id("dammage-detection-in-car", 9) is None

def test_remap_dataset3_severity():
    assert remap_class_id("car-damaged-severity-detection", 3) == 0
    assert remap_class_id("car-damaged-severity-detection", 6) == 1
    assert remap_class_id("car-damaged-severity-detection", 1) == 5

def test_remap_dataset4_direct():
    assert remap_class_id("car-damage-4-classes", 0) == 2
    assert remap_class_id("car-damage-4-classes", 1) == 0
    assert remap_class_id("car-damage-4-classes", 2) == 3
    assert remap_class_id("car-damage-4-classes", 3) == 1

def test_remap_unknown_dataset():
    assert remap_class_id("nonexistent-dataset", 0) is None

def test_drop_class_ids_dataset1():
    drops = DROP_CLASS_IDS["dammage-detection-in-car"]
    for expected_id in [0, 3, 7, 9, 12, 13, 18, 20, 23]:
        assert expected_id in drops
