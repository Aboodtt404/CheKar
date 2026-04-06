from carcheck.models import Detection, Finding, Severity, ConfidenceLevel, FindingSource, CLASS_NAMES_AR
from carcheck.costs.estimator import estimate_repair_cost


def _detection_to_finding(
    det: Detection,
    qwen_class: str | None = None,
    qwen_class_ar: str | None = None,
    qwen_severity: str | None = None,
    qwen_confidence: str | None = None,
    qwen_description: str | None = None,
    region: str = "cairo",
) -> Finding:
    """Convert a YOLO detection to a Finding, optionally overriding class with Qwen's.

    If Qwen provided a classification, use it (cross-checked).
    If not, fall back to YOLO's class.
    """
    # Determine final class: prefer Qwen's if available
    if qwen_class and qwen_class in CLASS_NAMES_AR:
        final_class = qwen_class
        final_class_ar = qwen_class_ar or CLASS_NAMES_AR.get(qwen_class, qwen_class)
        source = FindingSource.BOTH  # cross-checked by both
    else:
        final_class = det.class_name
        final_class_ar = det.class_name_ar
        source = FindingSource.YOLO

    # Determine severity
    if qwen_severity:
        severity = Severity(qwen_severity)
    else:
        severity = det.severity

    # Determine confidence
    if qwen_confidence:
        confidence = ConfidenceLevel(qwen_confidence)
    elif source == FindingSource.BOTH:
        confidence = ConfidenceLevel.HIGH  # both models agree on location
    else:
        confidence = ConfidenceLevel.HIGH

    cost = estimate_repair_cost(final_class, region=region)

    return Finding(
        type=final_class_ar,
        type_en=final_class,
        location=f"صورة: {det.image_path}" if det.image_path else "",
        location_en=f"Image: {det.image_path}" if det.image_path else "",
        severity=severity,
        confidence=confidence,
        source=source,
        cost_min=cost["min"] if cost else None,
        cost_max=cost["max"] if cost else None,
        note_ar=qwen_description or (cost["notes_ar"] if cost else ""),
    )


def merge_results(
    detections_per_image: list[list[Detection]],
    classified_detections: list[dict],
    exterior_findings: list[Finding],
    interior_findings: list[Finding],
    region: str = "cairo",
) -> tuple[list[Finding], list[Detection]]:
    """Merge YOLO detections with Qwen cross-checking.

    classified_detections: Qwen's classification of each YOLO region
        [{"region_id": 0, "class_en": "lamp_broken", "class_ar": "...", ...}, ...]
    exterior_findings: additional findings Qwen found beyond YOLO
    interior_findings: findings from interior analysis
    """
    all_detections: list[Detection] = []
    for dets in detections_per_image:
        all_detections.extend(dets)

    # Build lookup from region_id to Qwen's classification
    qwen_lookup: dict[int, dict] = {}
    for cd in classified_detections:
        rid = cd.get("region_id")
        if rid is not None:
            qwen_lookup[rid] = cd

    # Convert each YOLO detection to a Finding, cross-checked with Qwen
    # If Qwen says "no_damage" or "not_car", skip the detection entirely
    yolo_findings = []
    for i, det in enumerate(all_detections):
        qwen = qwen_lookup.get(i, {})
        qwen_class = qwen.get("class_en", "")
        if qwen_class in ("no_damage", "not_car", "false_positive"):
            continue  # Qwen overrides: this isn't real damage, drop it
        finding = _detection_to_finding(
            det,
            qwen_class=qwen.get("class_en"),
            qwen_class_ar=qwen.get("class_ar"),
            qwen_severity=qwen.get("severity"),
            qwen_confidence=qwen.get("confidence"),
            qwen_description=qwen.get("description_ar"),
            region=region,
        )
        yolo_findings.append(finding)

    all_findings = yolo_findings + exterior_findings + interior_findings
    return all_findings, all_detections
