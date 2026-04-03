import pytest
from pathlib import Path
from PIL import Image
import numpy as np

from carcheck.pipeline.image_annotator import annotate_image
from carcheck.models import Detection


@pytest.fixture
def sample_detection() -> Detection:
    return Detection(
        class_id=0,
        class_name="dent",
        class_name_ar="خبطة",
        confidence=0.87,
        bbox=[100, 200, 300, 400],
        mask_area_pixels=5000,
        image_area_pixels=480000,
        image_path="/tmp/test.jpg",
    )


def test_annotate_image_creates_output(tmp_path: Path, sample_detection: Detection):
    img = Image.new("RGB", (800, 600), color=(128, 128, 128))
    src = tmp_path / "src.jpg"
    img.save(src, "JPEG")

    out_path = annotate_image(src, [sample_detection], tmp_path / "annotated")
    assert out_path.exists()
    annotated = Image.open(out_path)
    assert annotated.size == (800, 600)


def test_annotate_image_no_detections(tmp_path: Path):
    img = Image.new("RGB", (800, 600), color=(128, 128, 128))
    src = tmp_path / "src.jpg"
    img.save(src, "JPEG")

    out_path = annotate_image(src, [], tmp_path / "annotated")
    assert out_path.exists()
