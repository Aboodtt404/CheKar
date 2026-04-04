from __future__ import annotations

import base64
import json
import re
from pathlib import Path

from openai import OpenAI

from carcheck.config import settings
from carcheck.models import Finding, ConfidenceLevel, Severity, FindingSource


def _load_prompt(name: str) -> str:
    path = settings.prompts_dir / f"{name}.txt"
    return path.read_text(encoding="utf-8")


def _strip_class_from_detections(detections_json: str) -> str:
    """Strip class labels from YOLO detections to avoid biasing Qwen.

    Keeps only: region_id, bbox coordinates, confidence, mask_area_pct.
    Removes: class_name, class_name_ar, class_id.
    """
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


def build_exterior_prompt(
    car_model: str,
    year: int,
    mileage: int,
    yolo_detections_json: str,
) -> str:
    template = _load_prompt("exterior_analysis")
    stripped_json = _strip_class_from_detections(yolo_detections_json)
    return template.format(
        car_model=car_model,
        year=year,
        mileage=mileage,
        detection_regions_json=stripped_json,
    )


def build_interior_prompt(
    car_model: str,
    year: int,
    mileage: int,
) -> str:
    template = _load_prompt("interior_docs")
    return template.format(
        car_model=car_model,
        year=year,
        mileage=mileage,
    )


def build_report_prompt(
    car_model: str,
    year: int,
    mileage: int,
    findings_json: str,
    cost_db_json: str,
    trust_score: int,
) -> str:
    template = _load_prompt("report_generation")
    return template.format(
        car_model=car_model,
        year=year,
        mileage=mileage,
        findings_json=findings_json,
        cost_db_json=cost_db_json,
        trust_score=trust_score,
    )


def parse_vlm_json_response(raw: str) -> dict:
    """Extract JSON from a VLM response that may contain markdown fences."""
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


class VLMAnalyzer:
    def __init__(self):
        self.client = OpenAI(
            base_url=settings.vlm_base_url,
            api_key="not-needed",
        )
        self.model = settings.vlm_model

    def _call(self, system: str, user_text: str, image_paths: list[Path] | None = None) -> str:
        user_content: list[dict] = []
        if image_paths:
            user_content.extend(_build_image_messages(image_paths))
        user_content.append({"type": "text", "text": user_text})

        response = self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user_content},
            ],
            max_tokens=settings.vlm_max_tokens,
            temperature=settings.vlm_temperature,
            extra_body={"chat_template_kwargs": {"enable_thinking": False}},
        )
        return response.choices[0].message.content

    def validate_car_photos(self, image_paths: list[Path]) -> tuple[bool, str]:
        """Check if the photos actually contain a car.

        Returns (is_valid, message_ar).
        is_valid: True if photos show a car, False if not.
        message_ar: Arabic explanation if invalid.
        """
        system = "أنت خبير فحص سيارات. رد بـ JSON فقط."
        user_text = (
            "شوف الصور دي وقولي: هل الصور دي لعربية (سيارة) ولا لأ؟\n\n"
            "رد بـ JSON كده:\n"
            '```json\n'
            '{"is_car": true, "message_ar": ""}\n'
            '```\n\n'
            "لو الصور مش لعربية، حط is_car: false واكتب في message_ar إيه اللي في الصور.\n"
            "لو الصور لعربية، حط is_car: true و message_ar فاضية."
        )

        try:
            raw = self._call(system, user_text, image_paths)
            parsed = parse_vlm_json_response(raw)
            is_car = parsed.get("is_car", True)
            message = parsed.get("message_ar", "")
            return (bool(is_car), message)
        except Exception:
            # If validation fails, assume valid and let the pipeline continue
            return (True, "")

    def analyze_exterior(self, image_paths, car_model, year, mileage, yolo_detections_json):
        """Analyze exterior photos. Returns (classified_detections, additional_findings).

        classified_detections: list of dicts with region_id + Qwen's class label
        additional_findings: list of Finding objects for things Qwen found beyond YOLO
        """
        system = "أنت خبير فحص سيارات مصري. رد بـ JSON فقط."
        user_text = build_exterior_prompt(car_model, year, mileage, yolo_detections_json)
        raw = self._call(system, user_text, image_paths)
        parsed = parse_vlm_json_response(raw)

        # Qwen's classification of each YOLO detection region
        classified = parsed.get("classified_detections", [])

        # Additional findings Qwen found beyond YOLO detections
        additional_findings = []
        for f in parsed.get("additional_findings", []):
            additional_findings.append(Finding(
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
            ))

        return classified, additional_findings

    def analyze_interior(self, image_paths, car_model, year, mileage):
        system = "أنت خبير فحص سيارات مصري. رد بـ JSON فقط."
        user_text = build_interior_prompt(car_model, year, mileage)
        raw = self._call(system, user_text, image_paths)
        parsed = parse_vlm_json_response(raw)
        metadata = {
            "odometer_reading": parsed.get("odometer_reading"),
            "odometer_matches_wear": parsed.get("odometer_matches_wear", True),
            "year_model_verified": parsed.get("year_model_verified", True),
        }
        findings = []
        for f in parsed.get("interior_findings", []):
            findings.append(Finding(
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
            ))
        return findings, metadata

    def generate_report(self, car_model, year, mileage, findings_json, cost_db_json, trust_score):
        system = "أنت كاتب تقارير فحص سيارات مصري. رد بـ JSON فقط."
        user_text = build_report_prompt(car_model, year, mileage, findings_json, cost_db_json, trust_score)
        raw = self._call(system, user_text)
        return parse_vlm_json_response(raw)
