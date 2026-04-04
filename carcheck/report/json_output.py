import json
from carcheck.models import InspectionResult


def inspection_to_arabic_json(result: InspectionResult) -> str:
    findings_ar = []
    for f in result.findings:
        entry = {
            "النوع": f.type,
            "الموقع": f.location,
            "الخطورة": "خطير" if f.severity.value == "major" else "بسيط",
            "مستوى_الثقة": {"high": "عالي", "medium": "متوسط", "low": "منخفض"}.get(f.confidence.value, f.confidence.value),
            "المصدر": f.source.value,
        }
        if f.cost_min is not None and f.cost_max is not None:
            entry["تكلفة_الإصلاح"] = {"من": f.cost_min, "إلى": f.cost_max, "العملة": "جنيه"}
        else:
            entry["تكلفة_الإصلاح"] = None
        if f.note_ar:
            entry["ملاحظة"] = f.note_ar
        findings_ar.append(entry)

    grade_result = result.grade_result

    if grade_result:
        categories_ar = {}
        for name, cat in grade_result.categories.items():
            cat_findings = []
            for f in cat.findings:
                cat_findings.append({
                    "النوع": f.type,
                    "الموقع": f.location,
                    "الخطورة": "خطير" if f.severity.value == "major" else "بسيط",
                })
            categories_ar[cat.name_ar] = {
                "الحالة": cat.light.value,
                "النتائج": cat_findings,
            }

        output = {
            "نتيجة_الفحص": {
                "التقييم": grade_result.grade,
                "التقييم_بالعربي": grade_result.grade_ar,
                "النصيحة": grade_result.recommendation_ar,
                "الفئات": categories_ar,
                "مالقدرناش_نفحص": grade_result.unassessed_areas_ar,
                "السيارة": {
                    "الموديل": result.input.car_model,
                    "السنة": result.input.year,
                    "الكيلومترات_المعلنة": result.input.mileage,
                },
                "النتائج": findings_ar,
                "ملخص": result.summary_ar,
                "التحذيرات": result.warnings,
                "إخلاء_مسؤولية": result.disclaimer_ar,
            }
        }
    else:
        # Fallback to legacy trust_score format
        sub_scores_ar = {}
        if result.trust_score:
            for key, ss in result.trust_score.sub_scores.items():
                sub_scores_ar[ss.name_ar] = {"الدرجة": ss.score, "الوزن": f"{ss.weight:.0%}"}

        output = {
            "نتيجة_الفحص": {
                "درجة_الثقة": result.trust_score.total if result.trust_score else None,
                "التصنيف": result.trust_score.label_ar if result.trust_score else "",
                "السيارة": {
                    "الموديل": result.input.car_model,
                    "السنة": result.input.year,
                    "الكيلومترات_المعلنة": result.input.mileage,
                },
                "النتائج": findings_ar,
                "الدرجات_الفرعية": sub_scores_ar,
                "ملخص": result.summary_ar,
                "التحذيرات": result.warnings,
                "إخلاء_مسؤولية": result.disclaimer_ar,
            }
        }

    return json.dumps(output, ensure_ascii=False, indent=2)


def inspection_to_english_json(result: InspectionResult) -> str:
    findings_en = []
    for f in result.findings:
        entry = {
            "type": f.type_en,
            "location": f.location_en,
            "severity": f.severity.value,
            "confidence": f.confidence.value,
            "source": f.source.value,
        }
        if f.cost_min is not None and f.cost_max is not None:
            entry["repair_cost_egp"] = {"min": f.cost_min, "max": f.cost_max}
        else:
            entry["repair_cost_egp"] = None
        findings_en.append(entry)

    grade_result = result.grade_result

    if grade_result:
        output = {
            "inspection_result": {
                "grade": grade_result.grade,
                "grade_ar": grade_result.grade_ar,
                "recommendation_ar": grade_result.recommendation_ar,
                "car": {
                    "model": result.input.car_model,
                    "year": result.input.year,
                    "mileage": result.input.mileage,
                },
                "findings": findings_en,
                "summary": result.summary_en,
                "disclaimer": result.disclaimer_en,
            }
        }
    else:
        output = {
            "inspection_result": {
                "trust_score": result.trust_score.total if result.trust_score else None,
                "label": result.trust_score.label_en if result.trust_score else "",
                "car": {
                    "model": result.input.car_model,
                    "year": result.input.year,
                    "mileage": result.input.mileage,
                },
                "findings": findings_en,
                "summary": result.summary_en,
                "disclaimer": result.disclaimer_en,
            }
        }

    return json.dumps(output, ensure_ascii=False, indent=2)
