from carcheck.models import (
    Detection,
    Finding,
    SubScore,
    TrustScoreResult,
)
from carcheck.scoring.deductions import (
    get_body_deduction,
    get_accident_deduction,
    get_flood_deduction,
    get_mechanical_deduction,
    get_docs_deduction,
)

# Findings that indicate fraud/serious issues — trigger a global score multiplier
_CRITICAL_FINDING_KEYS = {"odometer_mismatch", "year_model_failed"}
_CRITICAL_MULTIPLIER = 0.40


def get_score_label(score: int) -> tuple[str, str]:
    """Return (arabic_label, english_label) for a trust score."""
    if score >= 85:
        return ("اشتري بثقة", "Buy Confidently")
    if score >= 65:
        return ("فاوض على السعر", "Negotiate Price")
    if score >= 40:
        return ("اعمل فحص ميكانيكي", "Get Mechanic Inspection")
    return ("ابعد عن العربية دي", "Walk Away")


def calculate_trust_score(
    detections: list[Detection],
    findings: list[Finding],
) -> TrustScoreResult:
    """Calculate the 0-100 trust score from detections and findings."""

    body = SubScore(name="body", name_ar="حالة الهيكل", weight=0.30)
    accident = SubScore(name="accident", name_ar="احتمال حادث", weight=0.25)
    flood = SubScore(name="flood", name_ar="احتمال غرق", weight=0.15)
    mechanical = SubScore(name="mechanical", name_ar="الحالة الميكانيكية", weight=0.15)
    docs = SubScore(name="docs", name_ar="تطابق المستندات", weight=0.15)

    # Apply YOLO detection deductions to body score
    for det in detections:
        amount = get_body_deduction(det.class_name, det.severity)
        if amount > 0:
            body.deduct(amount, f"{det.class_name_ar} ({det.severity.value})")

    # Apply Qwen finding deductions to appropriate sub-scores
    category_map = {
        "accident": (accident, get_accident_deduction),
        "flood": (flood, get_flood_deduction),
        "mechanical": (mechanical, get_mechanical_deduction),
        "docs": (docs, get_docs_deduction),
    }

    has_critical_finding = False
    for finding in findings:
        cat = finding.finding_category
        key = finding.finding_key
        if cat in category_map and key:
            sub_score, deduction_fn = category_map[cat]
            amount = deduction_fn(key)
            if amount > 0:
                sub_score.deduct(amount, finding.type)
        if key in _CRITICAL_FINDING_KEYS:
            has_critical_finding = True

    sub_scores = {
        "body": body,
        "accident": accident,
        "flood": flood,
        "mechanical": mechanical,
        "docs": docs,
    }

    weighted_sum = sum(s.score * s.weight for s in sub_scores.values())

    # Critical findings (odometer fraud, fake year/model) tank the entire score
    if has_critical_finding:
        weighted_sum *= _CRITICAL_MULTIPLIER

    total = round(max(0, weighted_sum))
    label_ar, label_en = get_score_label(total)

    return TrustScoreResult(
        total=total,
        label_ar=label_ar,
        label_en=label_en,
        sub_scores=sub_scores,
    )
