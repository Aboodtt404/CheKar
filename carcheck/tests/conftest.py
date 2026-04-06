import pytest
from PIL import Image
from pathlib import Path


@pytest.fixture
def sample_image(tmp_path: Path) -> Path:
    """Create a simple 800x600 test image."""
    img = Image.new("RGB", (800, 600), color=(128, 128, 128))
    path = tmp_path / "test_car.jpg"
    img.save(path, "JPEG")
    return path


@pytest.fixture
def sample_image_small(tmp_path: Path) -> Path:
    """Create an image below minimum dimension."""
    img = Image.new("RGB", (320, 240), color=(128, 128, 128))
    path = tmp_path / "too_small.jpg"
    img.save(path, "JPEG")
    return path


@pytest.fixture
def sample_photos_dir(tmp_path: Path) -> Path:
    """Create a directory with 3 test images."""
    photos = tmp_path / "photos"
    photos.mkdir()
    for i in range(3):
        img = Image.new("RGB", (800, 600), color=(100 + i * 50, 100, 100))
        (photos / f"photo_{i}.jpg").save(img, "JPEG")
    return photos
