from pathlib import Path
from carcheck.models import InspectionResult
from carcheck.report.json_output import inspection_to_arabic_json, inspection_to_english_json
from carcheck.report.pdf_builder import build_pdf


def generate_report(
    result: InspectionResult,
    output_json: Path | None = None,
    output_pdf: Path | None = None,
    lang: str = "ar",
) -> dict[str, Path]:
    outputs: dict[str, Path] = {}
    if output_json:
        output_json.parent.mkdir(parents=True, exist_ok=True)
        if lang == "ar":
            content = inspection_to_arabic_json(result)
        else:
            content = inspection_to_english_json(result)
        output_json.write_text(content, encoding="utf-8")
        outputs["json"] = output_json
    if output_pdf:
        build_pdf(result, output_pdf)
        outputs["pdf"] = output_pdf
    return outputs
