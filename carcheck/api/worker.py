"""Huey background worker for running inspection pipeline."""
import json
import traceback
from pathlib import Path
from huey import SqliteHuey
from carcheck.config import settings

huey = SqliteHuey(filename="data/huey.db", immediate=False)

_detector = None
_vlm = None


def _get_detector():
    global _detector
    if _detector is None:
        from carcheck.pipeline.yolo_detector import YOLODetector
        _detector = YOLODetector()
    return _detector


def _get_vlm():
    global _vlm
    if _vlm is None:
        from carcheck.pipeline.vlm_analyzer import VLMAnalyzer
        _vlm = VLMAnalyzer()
    return _vlm


@huey.task(retries=1, retry_delay=30)
def run_inspection(inspection_id: str):
    import sqlite3

    db_path = "data/carcheck.db"
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row

    try:
        row = conn.execute("SELECT * FROM inspections WHERE id = ?", (inspection_id,)).fetchone()
        if row is None:
            return

        inspection = dict(row)
        photos_dir = Path(f"data/inspections/{inspection_id}/photos")

        from carcheck.pipeline.preprocessor import validate_photos_dir, preprocess_image
        from carcheck.pipeline.image_annotator import annotate_image
        from carcheck.pipeline.result_merger import merge_results
        from carcheck.scoring.grading import calculate_grade
        from carcheck.report.json_output import inspection_to_arabic_json, inspection_to_english_json
        from carcheck.report.pdf_builder import build_pdf
        from carcheck.models import InspectionInput, InspectionResult

        image_paths = validate_photos_dir(photos_dir)
        processed_dir = Path(f"data/inspections/{inspection_id}/_processed")
        processed_paths = [preprocess_image(p, processed_dir) for p in image_paths]

        detector = _get_detector()
        detections_per_image = detector.detect(processed_paths)

        annotated_dir = Path(f"data/inspections/{inspection_id}/_annotated")
        annotated_paths = []
        for path, dets in zip(processed_paths, detections_per_image):
            annotated_paths.append(annotate_image(path, dets, annotated_dir))

        vlm = _get_vlm()
        car_model = inspection["car_model"]
        year = inspection["year"]
        mileage = inspection["mileage"]
        region = inspection.get("region", "cairo")
        lang = inspection.get("lang", "ar")

        exterior_photos = annotated_paths[:8] if len(annotated_paths) >= 8 else annotated_paths
        interior_photos = annotated_paths[8:] if len(annotated_paths) > 8 else []

        # Validate photos are actually of a car
        is_car, validation_msg = vlm.validate_car_photos(exterior_photos[:3])  # check first 3 photos
        if not is_car:
            error_msg = validation_msg or "الصور مش لعربية — صور عربية حقيقية وحاول تاني"
            conn.execute(
                "UPDATE inspections SET status='failed', error_message=? WHERE id=?",
                (error_msg, inspection_id),
            )
            conn.commit()
            return

        dets_json = json.dumps(
            [d.model_dump() for dets in detections_per_image for d in dets],
            ensure_ascii=False,
        )

        classified_detections, exterior_findings = vlm.analyze_exterior(exterior_photos, car_model, year, mileage, dets_json)
        interior_findings, metadata = vlm.analyze_interior(interior_photos, car_model, year, mileage) if interior_photos else ([], {})

        all_findings, all_detections = merge_results(detections_per_image, classified_detections, exterior_findings, interior_findings, region)

        photo_count = len(image_paths)
        mode = "quick" if photo_count <= 8 else "full"
        grade_result = calculate_grade(all_detections, all_findings, mode=mode)

        cost_db_text = settings.cost_db_path.read_text(encoding="utf-8")
        report_data = vlm.generate_report(
            car_model, year, mileage,
            json.dumps([f.model_dump() for f in all_findings], ensure_ascii=False),
            cost_db_text, grade_result.grade,
        )

        inspection_input = InspectionInput(
            photos_dir=str(photos_dir), car_model=car_model,
            year=year, mileage=mileage, lang=lang, region=region,
        )
        result = InspectionResult(
            input=inspection_input, detections=all_detections,
            findings=all_findings, grade_result=grade_result,
            summary_ar=report_data.get("summary_ar", ""),
            warnings=report_data.get("warnings", []),
        )

        for f in all_findings:
            if f.confidence.value == "low" and f.finding_category == "accident":
                result.warnings.append("ننصح بفحص ميكانيكي للتأكد من حالة الدهان")
                break

        base_dir = Path(f"data/inspections/{inspection_id}")
        if lang == "ar":
            result_json_str = inspection_to_arabic_json(result)
        else:
            result_json_str = inspection_to_english_json(result)

        (base_dir / "report.json").write_text(result_json_str, encoding="utf-8")
        build_pdf(result, base_dir / "report.pdf")

        conn.execute(
            "UPDATE inspections SET status='completed', trust_score=?, result_json=?, completed_at=datetime('now') WHERE id=?",
            (0, result_json_str, inspection_id),
        )
        conn.commit()

    except Exception as e:
        raw_error = f"{type(e).__name__}: {str(e)}"
        # Show user-friendly error, not raw stack trace
        if "parse" in raw_error.lower() or "json" in raw_error.lower():
            error_msg = "حصل مشكلة في تحليل الصور. حاول تاني بصور أوضح."
        elif "timeout" in raw_error.lower() or "connect" in raw_error.lower():
            error_msg = "السيرفر مشغول. حاول تاني بعد شوية."
        elif "memory" in raw_error.lower() or "oom" in raw_error.lower():
            error_msg = "السيرفر مشغول. حاول تاني بعد شوية."
        else:
            error_msg = "حصل مشكلة غير متوقعة. حاول تاني."
        conn.execute("UPDATE inspections SET status='failed', error_message=? WHERE id=?", (error_msg, inspection_id))
        conn.commit()
        raise

    finally:
        conn.close()
