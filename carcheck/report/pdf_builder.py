from pathlib import Path
from carcheck.models import InspectionResult

_SCORE_COLORS = {"buy": "#28a745", "negotiate": "#ffc107", "inspect": "#fd7e14", "walk": "#dc3545"}

def _get_score_color(score: int) -> str:
    if score >= 85: return _SCORE_COLORS["buy"]
    if score >= 65: return _SCORE_COLORS["negotiate"]
    if score >= 40: return _SCORE_COLORS["inspect"]
    return _SCORE_COLORS["walk"]

def build_pdf(result: InspectionResult, output_path: Path) -> Path:
    from weasyprint import HTML
    from jinja2 import Environment, FileSystemLoader
    templates_dir = Path(__file__).parent / "templates"
    env = Environment(loader=FileSystemLoader(str(templates_dir)))
    template = env.get_template("report.html")
    score = result.trust_score.total if result.trust_score else 0
    score_color = _get_score_color(score)
    html_content = template.render(
        trust_score=score,
        score_label_ar=result.trust_score.label_ar if result.trust_score else "",
        score_color=score_color,
        car_model=result.input.car_model,
        year=result.input.year,
        mileage=result.input.mileage,
        summary_ar=result.summary_ar,
        findings=result.findings,
        warnings=result.warnings,
        disclaimer_ar=result.disclaimer_ar,
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    HTML(string=html_content).write_pdf(str(output_path))
    return output_path
