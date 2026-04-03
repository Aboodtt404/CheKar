"""End-to-end integration test with mocked AI models."""
import json
import pytest
from pathlib import Path
from PIL import Image

from carcheck.models import (
    InspectionInput, InspectionResult, Detection, Finding,
    Severity, ConfidenceLevel, FindingSource,
)
from carcheck.pipeline.preprocessor import validate_photos_dir, preprocess_image
from carcheck.pipeline.image_annotator import annotate_image
from carcheck.pipeline.result_merger import merge_results
from carcheck.scoring.trust_score import calculate_trust_score
from carcheck.report.json_output import inspection_to_arabic_json


@pytest.fixture
def inspection_photos(tmp_path: Path) -> Path:
    photos = tmp_path / "car_photos"
    photos.mkdir()
    for i in range(5):
        img = Image.new("RGB", (1024, 768), color=(120 + i * 20, 100, 80))
        img.save(photos / f"photo_{i:02d}.jpg", "JPEG")
    return photos


def _fake_detections() -> list[list[Detection]]:
    dets_img0 = [
        Detection(
            class_id=0, class_name="dent", class_name_ar="خبطة",
            confidence=0.85, bbox=[100, 200, 250, 350],
            mask_area_pixels=800, image_area_pixels=786432,
        ),
    ]
    dets_img1 = [
        Detection(
            class_id=0, class_name="dent", class_name_ar="خبطة",
            confidence=0.72, bbox=[300, 100, 500, 300],
            mask_area_pixels=25000, image_area_pixels=786432,
        ),
        Detection(
            class_id=1, class_name="scratch", class_name_ar="خدش",
            confidence=0.91, bbox=[50, 400, 200, 450],
            mask_area_pixels=500, image_area_pixels=786432,
        ),
    ]
    return [dets_img0, dets_img1, [], [], []]


def test_full_pipeline_mock(inspection_photos: Path, tmp_path: Path):
    image_paths = validate_photos_dir(inspection_photos)
    assert len(image_paths) == 5

    processed_dir = tmp_path / "processed"
    processed = [preprocess_image(p, processed_dir) for p in image_paths]
    assert all(p.exists() for p in processed)

    detections_per_image = _fake_detections()

    annotated_dir = tmp_path / "annotated"
    for path, dets in zip(processed, detections_per_image):
        annotate_image(path, dets, annotated_dir)

    exterior_findings = [
        Finding(
            type="احتمال إعادة دهان", type_en="Possible repaint",
            location="الرفرف الأمامي اليمين", location_en="Front right fender",
            severity=Severity.MAJOR, confidence=ConfidenceLevel.LOW,
            source=FindingSource.QWEN,
            finding_category="accident", finding_key="repaint_possible",
        ),
    ]

    all_findings, all_dets = merge_results(
        detections_per_image, exterior_findings, [],
    )
    assert len(all_findings) == 4
    assert len(all_dets) == 3

    trust_score = calculate_trust_score(all_dets, all_findings)
    assert 0 <= trust_score.total <= 100
    assert trust_score.label_ar != ""

    result = InspectionResult(
        input=InspectionInput(
            photos_dir=str(inspection_photos),
            car_model="Nissan Sunny", year=2019, mileage=85000,
        ),
        detections=all_dets, findings=all_findings,
        trust_score=trust_score,
        summary_ar="العربية فيها شوية خبطات وخدش بسيط واحتمال الرفرف متدهن",
    )

    json_output = inspection_to_arabic_json(result)
    parsed = json.loads(json_output)
    assert "نتيجة_الفحص" in parsed
    assert parsed["نتيجة_الفحص"]["درجة_الثقة"] == trust_score.total
    assert len(parsed["نتيجة_الفحص"]["النتائج"]) == 4
