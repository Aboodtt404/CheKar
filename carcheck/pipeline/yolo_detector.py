from __future__ import annotations

from pathlib import Path

import numpy as np

from carcheck.config import settings
from carcheck.models import Detection, CLASS_NAMES_AR


# CarDD 6-class standard
CARDD_CLASSES = {
    0: "dent",
    1: "scratch",
    2: "crack",
    3: "glass_shatter",
    4: "lamp_broken",
    5: "tire_flat",
}


def parse_yolo_results(
    result,
    class_names: dict[int, str] | None = None,
) -> list[Detection]:
    """Convert a single YOLO result object to a list of Detection models."""
    if class_names is None:
        class_names = CARDD_CLASSES

    boxes = result.boxes
    if len(boxes.cls) == 0:
        return []

    h, w = result.orig_shape
    image_area = h * w

    detections = []
    classes = boxes.cls.cpu().numpy() if hasattr(boxes.cls, "cpu") else np.array(boxes.cls)
    confs = boxes.conf.cpu().numpy() if hasattr(boxes.conf, "cpu") else np.array(boxes.conf)
    xyxys = boxes.xyxy.cpu().numpy() if hasattr(boxes.xyxy, "cpu") else np.array(boxes.xyxy)

    masks_data = None
    if result.masks is not None:
        masks_data = result.masks.data
        if hasattr(masks_data, "cpu"):
            masks_data = masks_data.cpu().numpy()

    for i in range(len(classes)):
        cls_id = int(classes[i])
        cls_name = class_names.get(cls_id, f"class_{cls_id}")

        mask_pixels = 0
        if masks_data is not None and i < len(masks_data):
            mask_pixels = int(np.sum(masks_data[i] > 0.5))

        detections.append(
            Detection(
                class_id=cls_id,
                class_name=cls_name,
                class_name_ar=CLASS_NAMES_AR.get(cls_name, cls_name),
                confidence=float(confs[i]),
                bbox=xyxys[i].tolist(),
                mask_area_pixels=mask_pixels,
                image_area_pixels=image_area,
                image_path=str(getattr(result, "path", "")),
            )
        )

    return detections


class YOLODetector:
    """Wrapper around ultralytics YOLO for car damage detection."""

    def __init__(self, weights_path: Path | None = None):
        if weights_path is None:
            weights_path = settings.models_dir / settings.yolo_weights

        if not weights_path.exists():
            raise FileNotFoundError(f"YOLO weights not found: {weights_path}")

        from ultralytics import YOLO

        self.model = YOLO(str(weights_path))
        self.class_names = CARDD_CLASSES

    def detect(self, image_paths: list[Path]) -> list[list[Detection]]:
        """Run inference on a list of images. Returns detections per image."""
        results = self.model(
            [str(p) for p in image_paths],
            conf=settings.yolo_confidence,
            iou=settings.yolo_iou,
            imgsz=settings.yolo_img_size,
            device=settings.yolo_device,
            verbose=False,
        )

        all_detections = []
        for result in results:
            detections = parse_yolo_results(result, self.class_names)
            all_detections.append(detections)

        return all_detections
