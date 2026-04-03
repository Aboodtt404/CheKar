from carcheck.models import Detection, Finding, Severity, ConfidenceLevel, FindingSource
from carcheck.costs.estimator import estimate_repair_cost


def _detection_to_finding(det: Detection, region: str = "cairo") -> Finding:
    cost = estimate_repair_cost(det.class_name, region=region)
    return Finding(
        type=det.class_name_ar,
        type_en=det.class_name,
        location=f"صورة: {det.image_path}" if det.image_path else "",
        location_en=f"Image: {det.image_path}" if det.image_path else "",
        severity=det.severity,
        confidence=ConfidenceLevel.HIGH,
        source=FindingSource.YOLO,
        cost_min=cost["min"] if cost else None,
        cost_max=cost["max"] if cost else None,
        note_ar=cost["notes_ar"] if cost else "",
    )


def merge_results(
    detections_per_image: list[list[Detection]],
    exterior_findings: list[Finding],
    interior_findings: list[Finding],
    region: str = "cairo",
) -> tuple[list[Finding], list[Detection]]:
    all_detections: list[Detection] = []
    for dets in detections_per_image:
        all_detections.extend(dets)
    yolo_findings = [_detection_to_finding(d, region) for d in all_detections]
    all_findings = yolo_findings + exterior_findings + interior_findings
    return all_findings, all_detections
