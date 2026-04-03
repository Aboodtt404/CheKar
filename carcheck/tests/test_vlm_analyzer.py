import pytest
from unittest.mock import patch, MagicMock, AsyncMock
from pathlib import Path

from carcheck.pipeline.vlm_analyzer import (
    VLMAnalyzer,
    build_exterior_prompt,
    build_interior_prompt,
    build_report_prompt,
    parse_vlm_json_response,
)


def test_build_exterior_prompt():
    prompt = build_exterior_prompt(
        car_model="Nissan Sunny",
        year=2019,
        mileage=85000,
        yolo_detections_json='[{"class": "dent"}]',
    )
    assert "Nissan Sunny" in prompt
    assert "2019" in prompt
    assert "85000" in prompt
    assert "dent" in prompt


def test_build_interior_prompt():
    prompt = build_interior_prompt(
        car_model="Nissan Sunny",
        year=2019,
        mileage=85000,
    )
    assert "Nissan Sunny" in prompt
    assert "85000" in prompt


def test_build_report_prompt():
    prompt = build_report_prompt(
        car_model="Nissan Sunny",
        year=2019,
        mileage=85000,
        findings_json="[]",
        cost_db_json="{}",
        trust_score=72,
    )
    assert "72" in prompt


def test_parse_vlm_json_response_clean():
    raw = '{"exterior_findings": []}'
    parsed = parse_vlm_json_response(raw)
    assert parsed == {"exterior_findings": []}


def test_parse_vlm_json_response_with_markdown():
    raw = '```json\n{"exterior_findings": []}\n```'
    parsed = parse_vlm_json_response(raw)
    assert parsed == {"exterior_findings": []}


def test_parse_vlm_json_response_invalid():
    raw = "This is not JSON at all"
    with pytest.raises(ValueError, match="parse"):
        parse_vlm_json_response(raw)
