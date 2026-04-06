import pytest
from pathlib import Path
from PIL import Image

from carcheck.pipeline.preprocessor import preprocess_image, validate_photos_dir


def test_preprocess_resizes_large_image(tmp_path: Path):
    img = Image.new("RGB", (4000, 3000), color=(128, 128, 128))
    path = tmp_path / "large.jpg"
    img.save(path, "JPEG")

    result = preprocess_image(path, tmp_path / "out")
    processed = Image.open(result)
    assert max(processed.size) <= 2048


def test_preprocess_keeps_small_image(tmp_path: Path):
    img = Image.new("RGB", (800, 600), color=(128, 128, 128))
    path = tmp_path / "ok.jpg"
    img.save(path, "JPEG")

    result = preprocess_image(path, tmp_path / "out")
    processed = Image.open(result)
    assert processed.size == (800, 600)


def test_preprocess_rejects_too_small(tmp_path: Path):
    img = Image.new("RGB", (320, 240), color=(128, 128, 128))
    path = tmp_path / "tiny.jpg"
    img.save(path, "JPEG")

    with pytest.raises(ValueError, match="too small"):
        preprocess_image(path, tmp_path / "out")


def test_preprocess_rejects_non_image(tmp_path: Path):
    path = tmp_path / "not_image.txt"
    path.write_text("hello")

    with pytest.raises(ValueError, match="not a valid image"):
        preprocess_image(path, tmp_path / "out")


def test_validate_photos_dir(tmp_path: Path):
    photos = tmp_path / "photos"
    photos.mkdir()
    for i in range(3):
        img = Image.new("RGB", (800, 600), color=(100, 100, 100))
        img.save(photos / f"photo_{i}.jpg", "JPEG")

    paths = validate_photos_dir(photos)
    assert len(paths) == 3


def test_validate_photos_dir_empty(tmp_path: Path):
    photos = tmp_path / "empty"
    photos.mkdir()

    with pytest.raises(ValueError, match="No valid images"):
        validate_photos_dir(photos)
