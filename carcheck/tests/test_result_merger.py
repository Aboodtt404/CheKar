from carcheck.pipeline.result_merger import merge_results
from carcheck.models import Detection, Finding, Severity, ConfidenceLevel, FindingSource


def test_merge_yolo_only_no_crosscheck():
    """YOLO detection with no Qwen classification falls back to YOLO class."""
    detections = [
        Detection(
            class_id=0, class_name="dent", class_name_ar="خبطة",
            confidence=0.87, bbox=[100, 200, 300, 400],
            mask_area_pixels=500, image_area_pixels=480000,
        ),
    ]
    findings, all_detections = merge_results(
        detections_per_image=[detections],
        classified_detections=[],
        exterior_findings=[],
        interior_findings=[],
    )
    assert len(findings) == 1
    assert findings[0].source == FindingSource.YOLO
    assert findings[0].type == "خبطة"


def test_merge_crosscheck_overrides_yolo():
    """Qwen classification overrides YOLO class when provided."""
    detections = [
        Detection(
            class_id=3, class_name="glass_shatter", class_name_ar="زجاج مكسور",
            confidence=0.95, bbox=[100, 200, 300, 400],
            mask_area_pixels=5000, image_area_pixels=480000,
        ),
    ]
    classified = [
        {"region_id": 0, "class_en": "lamp_broken", "class_ar": "لمبة مكسورة",
         "severity": "major", "confidence": "high", "description_ar": "اللمبة مكسورة"}
    ]
    findings, _ = merge_results(
        detections_per_image=[detections],
        classified_detections=classified,
        exterior_findings=[],
        interior_findings=[],
    )
    assert len(findings) == 1
    assert findings[0].type_en == "lamp_broken"  # Qwen overrode glass_shatter
    assert findings[0].type == "لمبة مكسورة"
    assert findings[0].source == FindingSource.BOTH


def test_merge_includes_additional_findings():
    """Additional findings from Qwen are included."""
    qwen_finding = Finding(
        type="احتمال إعادة دهان", type_en="Possible repaint",
        location="الرفرف", location_en="Fender",
        severity=Severity.MAJOR, confidence=ConfidenceLevel.LOW,
        source=FindingSource.QWEN,
        finding_category="accident", finding_key="repaint_possible",
    )
    findings, _ = merge_results(
        detections_per_image=[],
        classified_detections=[],
        exterior_findings=[qwen_finding],
        interior_findings=[],
    )
    assert len(findings) == 1
    assert findings[0].source == FindingSource.QWEN


def test_merge_combines_all_sources():
    """Cross-checked YOLO + additional exterior + interior all merge."""
    det = Detection(
        class_id=1, class_name="scratch", class_name_ar="خدش",
        confidence=0.9, bbox=[0, 0, 50, 50],
        mask_area_pixels=100, image_area_pixels=480000,
    )
    classified = [
        {"region_id": 0, "class_en": "scratch", "class_ar": "خدش",
         "severity": "minor", "confidence": "high", "description_ar": "خدش بسيط"}
    ]
    ext_finding = Finding(
        type="إعادة دهان محتملة", type_en="Possible repaint",
        location="الباب", location_en="Door",
        severity=Severity.MAJOR, confidence=ConfidenceLevel.LOW,
        source=FindingSource.QWEN,
        finding_category="accident", finding_key="repaint_possible",
    )
    int_finding = Finding(
        type="بقع مياه", type_en="Water stains",
        location="المقاعد", location_en="Seats",
        severity=Severity.MAJOR, confidence=ConfidenceLevel.MEDIUM,
        source=FindingSource.QWEN,
        finding_category="flood", finding_key="water_stain",
    )
    findings, all_dets = merge_results(
        detections_per_image=[[det]],
        classified_detections=classified,
        exterior_findings=[ext_finding],
        interior_findings=[int_finding],
    )
    assert len(findings) == 3
    assert len(all_dets) == 1
    assert findings[0].source == FindingSource.BOTH  # cross-checked
