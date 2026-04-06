import pytest
from unittest.mock import MagicMock, patch
from pathlib import Path
from PIL import Image

from carcheck.pipeline.yolo_detector import YOLODetector, parse_yolo_results
from carcheck.models import Detection


def test_parse_yolo_results_empty():
    """No detections returns empty list."""
    mock_result = MagicMock()
    mock_result.boxes = MagicMock()
    mock_result.boxes.cls = []
    mock_result.boxes.conf = []
    mock_result.boxes.xyxy = []
    mock_result.masks = None
    mock_result.orig_shape = (600, 800)
    mock_result.path = "/tmp/test.jpg"

    detections = parse_yolo_results(mock_result, class_names={0: "dent", 1: "scratch"})
    assert detections == []


def test_parse_yolo_results_with_detections():
    """Parse a mocked YOLO result with one detection."""
    import numpy as np

    mock_result = MagicMock()
    mock_result.boxes.cls = np.array([0])
    mock_result.boxes.conf = np.array([0.87])
    mock_result.boxes.xyxy = np.array([[100, 200, 300, 400]])
    mock_mask = np.zeros((600, 800), dtype=np.uint8)
    mock_mask[200:400, 100:300] = 1  # 200x200 = 40000 pixels
    mock_result.masks.data = np.array([mock_mask])
    mock_result.orig_shape = (600, 800)
    mock_result.path = "/tmp/test.jpg"

    class_names = {0: "dent", 1: "scratch"}
    detections = parse_yolo_results(mock_result, class_names=class_names)

    assert len(detections) == 1
    assert detections[0].class_name == "dent"
    assert detections[0].class_name_ar == "خبطة"
    assert detections[0].confidence == pytest.approx(0.87, rel=1e-2)
    assert detections[0].mask_area_pixels == 40000
    assert detections[0].image_area_pixels == 480000


def test_yolo_detector_init_with_missing_weights():
    """Detector raises if weights file doesn't exist."""
    with pytest.raises(FileNotFoundError):
        YOLODetector(weights_path=Path("/nonexistent/model.pt"))
