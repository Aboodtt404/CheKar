from __future__ import annotations

import base64
import json
import logging
import re
from pathlib import Path

from openai import OpenAI

from carcheck.config import settings
from carcheck.models import Finding, ConfidenceLevel, Severity, FindingSource
from carcheck.pipeline.vlm_schemas import (
    VALIDATION_SCHEMA,
    DETECTION_CLASSIFICATION_SCHEMA,
    FULL_ASSESSMENT_SCHEMA,
    INTERIOR_ANALYSIS_SCHEMA,
    REPORT_GENERATION_SCHEMA,
    build_response_format,
)

logger = logging.getLogger("carcheck.vlm")


def _load_prompt(name: str) -> str:
    path = settings.prompts_dir / f"{name}.txt"
    return path.read_text(encoding="utf-8")


def _strip_class_from_detections(detections_json: str) -> str:
    """Strip class labels from YOLO detections to avoid biasing Qwen."""
    detections = json.loads(detections_json)
    stripped = []
    for i, det in enumerate(detections):
        stripped.append({
            "region_id": i,
            "bbox": det.get("bbox", []),
            "confidence": det.get("confidence", 0),
            "mask_area_pct": det.get("mask_area_pct", 0),
            "image_path": det.get("image_path", ""),
        })
    return json.dumps(stripped, ensure_ascii=False)


def parse_vlm_json_response(raw: str) -> dict:
    """Extract JSON from a VLM response (fallback for non-guided responses)."""
    cleaned = raw.strip()
    match = re.search(r"```(?:json)?\s*\n?(.*?)```", cleaned, re.DOTALL)
    if match:
        cleaned = match.group(1).strip()
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError as e:
        raise ValueError(f"Failed to parse VLM JSON response: {e}\nRaw: {raw[:500]}")


def _image_to_base64_url(image_path: Path) -> str:
    data = image_path.read_bytes()
    b64 = base64.b64encode(data).decode("utf-8")
    return f"data:image/jpeg;base64,{b64}"


def _build_image_messages(image_paths: list[Path]) -> list[dict]:
    content = []
    for p in image_paths:
        content.append({
            "type": "image_url",
            "image_url": {"url": _image_to_base64_url(p)},
        })
    return content


def _parse_finding(f: dict) -> Finding:
    """Convert a raw finding dict to a Finding model object."""
    return Finding(
        type=f.get("type", ""),
        type_en=f.get("type_en", ""),
        location=f.get("location", ""),
        location_en=f.get("location_en", ""),
        severity=Severity(f.get("severity", "minor")),
        confidence=ConfidenceLevel(f.get("confidence", "medium")),
        source=FindingSource.QWEN,
        finding_category=f.get("finding_category", ""),
        finding_key=f.get("finding_key", ""),
        note_ar=f.get("description_ar", ""),
    )


class VLMAnalyzer:
    def __init__(self):
        self.client = OpenAI(
            base_url=settings.vlm_base_url,
            api_key="not-needed",
        )
        self.model = settings.vlm_model

    def _call(
        self,
        system: str,
        user_text: str,
        image_paths: list[Path] | None = None,
        response_format: dict | None = None,
        max_tokens: int | None = None,
    ) -> str:
        user_content: list[dict] = []
        if image_paths:
            user_content.extend(_build_image_messages(image_paths))
        user_content.append({"type": "text", "text": user_text})

        kwargs = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user_content},
            ],
            "max_tokens": max_tokens or settings.vlm_max_tokens,
            "temperature": settings.vlm_temperature,
            "extra_body": {"chat_template_kwargs": {"enable_thinking": False}},
        }
        if response_format is not None:
            kwargs["response_format"] = response_format

        response = self.client.chat.completions.create(**kwargs)
        return response.choices[0].message.content

    # ── Validation ───────────────────────────────────────────────────────

    def validate_car_photos(self, image_paths: list[Path]) -> tuple[bool, str]:
        """Check if the photos actually contain a car."""
        system = "أنت خبير فحص سيارات. رد بـ JSON فقط."
        user_text = (
            "شوف الصور دي وقولي: هل الصور دي لعربية (سيارة) ولا لأ؟\n\n"
            "لو الصور مش لعربية، حط is_car: false واكتب في message_ar إيه اللي في الصور.\n"
            "لو الصور لعربية، حط is_car: true و message_ar فاضية."
        )
        try:
            raw = self._call(
                system, user_text, image_paths,
                response_format=build_response_format("validation", VALIDATION_SCHEMA),
                max_tokens=settings.vlm_max_tokens_validation,
            )
            parsed = json.loads(raw)
            return (bool(parsed.get("is_car", True)), parsed.get("message_ar", ""))
        except Exception:
            return (True, "")

    # ── Exterior: Pass 1 — Detection Classification ──────────────────────

    def classify_detections(
        self, image_paths: list[Path], car_model: str, year: int, mileage: int, yolo_detections_json: str,
    ) -> list[dict]:
        """Pass 1: Classify each YOLO detection region independently."""
        logger.info("Pass 1: classifying YOLO detections")
        system = "أنت خبير فحص سيارات مصري. رد بـ JSON فقط."
        template = _load_prompt("detection_classification")
        stripped_json = _strip_class_from_detections(yolo_detections_json)
        user_text = template.format(
            car_model=car_model, year=year, mileage=mileage,
            detection_regions_json=stripped_json,
        )
        raw = self._call(
            system, user_text, image_paths,
            response_format=build_response_format("detection_classification", DETECTION_CLASSIFICATION_SCHEMA),
            max_tokens=settings.vlm_max_tokens_classification,
        )
        parsed = json.loads(raw)
        classified = parsed.get("classified_detections", [])
        logger.info("Pass 1 complete: %d detections classified", len(classified))
        return classified

    # ── Exterior: Pass 2 — Full Assessment ────────────────────────────────

    def assess_exterior(
        self, image_paths: list[Path], car_model: str, year: int, mileage: int, classified_detections_json: str,
    ) -> list[Finding]:
        """Pass 2: Find additional damage, repaint, panel misalignment."""
        logger.info("Pass 2: assessing exterior for additional findings")
        system = "أنت خبير فحص سيارات مصري. رد بـ JSON فقط."
        template = _load_prompt("exterior_assessment")
        user_text = template.format(
            car_model=car_model, year=year, mileage=mileage,
            classified_detections_json=classified_detections_json,
        )
        raw = self._call(
            system, user_text, image_paths,
            response_format=build_response_format("exterior_assessment", FULL_ASSESSMENT_SCHEMA),
            max_tokens=settings.vlm_max_tokens_assessment,
        )
        parsed = json.loads(raw)
        findings = [_parse_finding(f) for f in parsed.get("additional_findings", [])]
        logger.info(
            "Pass 2 complete: %d additional findings, repaint=%s, misalignment=%s",
            len(findings), parsed.get("repaint_detected"), parsed.get("panel_misalignment_detected"),
        )
        return findings

    # ── Exterior: Combined wrapper (backward compat) ──────────────────────

    def analyze_exterior(self, image_paths, car_model, year, mileage, yolo_detections_json):
        """Analyze exterior photos with 2-pass pipeline.

        Returns (classified_detections, additional_findings).
        """
        # Pass 1
        try:
            classified = self.classify_detections(
                image_paths, car_model, year, mileage, yolo_detections_json,
            )
        except Exception as e:
            logger.warning("Pass 1 (classify_detections) failed: %s — using empty classifications", e)
            classified = []

        # Pass 2
        try:
            classified_json = json.dumps(classified, ensure_ascii=False)
            additional = self.assess_exterior(
                image_paths, car_model, year, mileage, classified_json,
            )
        except Exception as e:
            logger.warning("Pass 2 (assess_exterior) failed: %s — skipping additional findings", e)
            additional = []

        return classified, additional

    # ── Interior ──────────────────────────────────────────────────────────

    def analyze_interior(self, image_paths, car_model, year, mileage):
        system = "أنت خبير فحص سيارات مصري. رد بـ JSON فقط."
        template = _load_prompt("interior_docs")
        user_text = template.format(car_model=car_model, year=year, mileage=mileage)
        raw = self._call(
            system, user_text, image_paths,
            response_format=build_response_format("interior_analysis", INTERIOR_ANALYSIS_SCHEMA),
            max_tokens=settings.vlm_max_tokens_interior,
        )
        parsed = json.loads(raw)
        metadata = {
            "odometer_reading": parsed.get("odometer_reading"),
            "odometer_matches_wear": parsed.get("odometer_matches_wear", True),
            "year_model_verified": parsed.get("year_model_verified", True),
        }
        findings = [_parse_finding(f) for f in parsed.get("interior_findings", [])]
        return findings, metadata

    # ── Report Generation ─────────────────────────────────────────────────

    def generate_report(self, car_model, year, mileage, findings_json, cost_db_json, trust_score):
        system = "أنت كاتب تقارير فحص سيارات مصري. رد بـ JSON فقط."
        template = _load_prompt("report_generation")
        user_text = template.format(
            car_model=car_model, year=year, mileage=mileage,
            findings_json=findings_json, cost_db_json=cost_db_json, trust_score=trust_score,
        )
        raw = self._call(
            system, user_text,
            response_format=build_response_format("report_generation", REPORT_GENERATION_SCHEMA),
            max_tokens=settings.vlm_max_tokens_report,
        )
        return json.loads(raw)
