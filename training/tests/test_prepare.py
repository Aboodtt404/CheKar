import pytest
from pathlib import Path
from PIL import Image
from training.prepare_data import remap_label_file, filter_small_images, compute_image_hash, deduplicate_images

def _write_label(path, lines):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")

def _write_image(path, width=640, height=640):
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGB", (width, height), (128, 128, 128)).save(path, "JPEG")

def test_remap_label_file_basic(tmp_path):
    label = tmp_path / "label.txt"
    _write_label(label, ["1 0.5 0.5 0.2 0.3", "8 0.3 0.3 0.1 0.1"])
    out = tmp_path / "out.txt"
    result = remap_label_file(label, out, "dammage-detection-in-car")
    assert result is True
    lines = out.read_text().strip().split("\n")
    assert lines[0].startswith("0 ")
    assert lines[1].startswith("4 ")

def test_remap_label_file_drops_no_damage(tmp_path):
    label = tmp_path / "label.txt"
    _write_label(label, ["0 0.5 0.5 0.2 0.3", "9 0.3 0.3 0.1 0.1"])
    out = tmp_path / "out.txt"
    result = remap_label_file(label, out, "dammage-detection-in-car")
    assert result is False
    assert out.read_text().strip() == ""

def test_remap_label_file_mixed(tmp_path):
    label = tmp_path / "label.txt"
    _write_label(label, ["0 0.5 0.5 0.2 0.3", "1 0.3 0.3 0.1 0.1", "9 0.2 0.2 0.05 0.05"])
    out = tmp_path / "out.txt"
    result = remap_label_file(label, out, "dammage-detection-in-car")
    assert result is True
    lines = out.read_text().strip().split("\n")
    assert len(lines) == 1
    assert lines[0].startswith("0 ")

def test_remap_dataset4(tmp_path):
    label = tmp_path / "label.txt"
    _write_label(label, ["0 0.5 0.5 0.2 0.3", "2 0.3 0.3 0.1 0.1"])
    out = tmp_path / "out.txt"
    result = remap_label_file(label, out, "car-damage-4-classes")
    assert result is True
    lines = out.read_text().strip().split("\n")
    assert lines[0].startswith("2 ")
    assert lines[1].startswith("3 ")

def test_filter_small_images(tmp_path):
    good = tmp_path / "good.jpg"
    bad = tmp_path / "bad.jpg"
    _write_image(good, 640, 640)
    _write_image(bad, 200, 150)
    result = filter_small_images([good, bad], min_dim=400)
    assert good in result
    assert bad not in result

def test_compute_image_hash(tmp_path):
    img1 = tmp_path / "img1.jpg"
    img2 = tmp_path / "img2.jpg"
    _write_image(img1)
    _write_image(img2)
    assert compute_image_hash(img1) == compute_image_hash(img2)

def test_deduplicate_images(tmp_path):
    import numpy as np
    img_a = tmp_path / "a.jpg"
    img_b = tmp_path / "b.jpg"
    img_c = tmp_path / "c.jpg"
    # a and b are identical textured images
    np.random.seed(42)
    arr = np.random.randint(0, 255, (640, 640, 3), dtype=np.uint8)
    Image.fromarray(arr).save(img_a)
    Image.fromarray(arr).save(img_b)  # duplicate of a
    # c is a completely different textured image
    np.random.seed(999)
    arr2 = np.random.randint(0, 255, (640, 640, 3), dtype=np.uint8)
    Image.fromarray(arr2).save(img_c)
    unique = deduplicate_images([img_a, img_b, img_c], threshold=5)
    assert len(unique) == 2
    assert img_c in unique
