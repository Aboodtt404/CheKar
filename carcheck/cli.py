from pathlib import Path
from typing import Optional

import typer

app = typer.Typer(name="carcheck", help="CarCheck — AI-powered car inspection for Egypt")


@app.command()
def inspect(
    photos_dir: Path = typer.Argument(..., help="Directory containing car photos"),
    car_model: str = typer.Option(..., "--car-model", "-m", help="Car model (e.g., 'Nissan Sunny')"),
    year: int = typer.Option(..., "--year", "-y", help="Car manufacturing year"),
    mileage: int = typer.Option(..., "--mileage", "-k", help="Stated mileage in km"),
    output_json: Optional[Path] = typer.Option(None, "--output-json", "-j", help="Path for JSON report"),
    output_pdf: Optional[Path] = typer.Option(None, "--output-pdf", "-p", help="Path for PDF report"),
    lang: str = typer.Option("ar", "--lang", "-l", help="Output language: ar (default) or en"),
    region: str = typer.Option("cairo", "--region", "-r", help="Region for cost estimates: cairo, alexandria"),
) -> None:
    """Run a full AI inspection on car photos."""
    import json
    from rich.console import Console
    from rich.panel import Panel

    from carcheck.config import settings
    from carcheck.models import InspectionInput, InspectionResult
    from carcheck.pipeline.preprocessor import validate_photos_dir, preprocess_image
    from carcheck.pipeline.yolo_detector import YOLODetector
    from carcheck.pipeline.image_annotator import annotate_image
    from carcheck.pipeline.vlm_analyzer import VLMAnalyzer
    from carcheck.pipeline.result_merger import merge_results
    from carcheck.scoring.trust_score import calculate_trust_score
    from carcheck.report.generator import generate_report

    console = Console()
    console.print("[bold]CarCheck AI Inspection[/bold]\n")
    image_paths = validate_photos_dir(photos_dir)
    console.print(f"Found {len(image_paths)} photos in {photos_dir}")

    inspection_input = InspectionInput(
        photos_dir=str(photos_dir), car_model=car_model,
        year=year, mileage=mileage, lang=lang, region=region,
    )

    console.print("Preprocessing images...")
    processed_dir = photos_dir / "_processed"
    processed_paths = [preprocess_image(p, processed_dir) for p in image_paths]

    console.print("Running YOLO11 damage detection...")
    detector = YOLODetector()
    detections_per_image = detector.detect(processed_paths)
    total_dets = sum(len(d) for d in detections_per_image)
    console.print(f"  Found {total_dets} damage instances across {len(image_paths)} photos")

    console.print("Annotating photos with detections...")
    annotated_dir = photos_dir / "_annotated"
    annotated_paths = []
    for path, dets in zip(processed_paths, detections_per_image):
        annotated_paths.append(annotate_image(path, dets, annotated_dir))

    console.print("Running Qwen3.5 vision analysis...")
    vlm = VLMAnalyzer()
    exterior_photos = annotated_paths[:8] if len(annotated_paths) >= 8 else annotated_paths
    interior_photos = annotated_paths[8:] if len(annotated_paths) > 8 else []

    dets_json = json.dumps(
        [d.model_dump() for dets in detections_per_image for d in dets],
        ensure_ascii=False,
    )

    console.print("  Call 1/3: Exterior analysis...")
    exterior_findings = vlm.analyze_exterior(
        exterior_photos, car_model, year, mileage, dets_json,
    )

    console.print("  Call 2/3: Interior & documentation...")
    interior_findings, metadata = vlm.analyze_interior(
        interior_photos, car_model, year, mileage,
    ) if interior_photos else ([], {})

    console.print("Merging results...")
    all_findings, all_detections = merge_results(
        detections_per_image, exterior_findings, interior_findings, region,
    )

    trust_score = calculate_trust_score(all_detections, all_findings)

    console.print("  Call 3/3: Generating Arabic report...")
    cost_db_text = settings.cost_db_path.read_text(encoding="utf-8")
    report_data = vlm.generate_report(
        car_model, year, mileage,
        json.dumps([f.model_dump() for f in all_findings], ensure_ascii=False),
        cost_db_text, trust_score.total,
    )

    result = InspectionResult(
        input=inspection_input, detections=all_detections,
        findings=all_findings, trust_score=trust_score,
        summary_ar=report_data.get("summary_ar", ""),
        warnings=report_data.get("warnings", []),
    )

    for f in all_findings:
        if f.confidence.value == "low" and f.finding_category == "accident":
            result.warnings.append("ننصح بفحص ميكانيكي للتأكد من حالة الدهان")
            break

    if not output_json and not output_pdf:
        output_json = photos_dir / "report.json"

    outputs = generate_report(result, output_json, output_pdf, lang)

    score_color = "green" if trust_score.total >= 85 else "yellow" if trust_score.total >= 65 else "red"
    console.print(Panel(
        f"[bold {score_color}]{trust_score.total}/100 — {trust_score.label_ar}[/bold {score_color}]",
        title="درجة الثقة", expand=False,
    ))
    console.print(f"\nFindings: {len(all_findings)}")
    for f in all_findings:
        icon = "[red]![/red]" if f.severity.value == "major" else "[yellow]*[/yellow]"
        console.print(f"  {icon} {f.type} — {f.location}")

    for fmt, path in outputs.items():
        console.print(f"\n[green]{fmt.upper()} report saved to: {path}[/green]")


@app.command()
def detect(
    photos_dir: Path = typer.Argument(..., help="Directory containing car photos"),
) -> None:
    """Run YOLO detection only (no VLM analysis). Quick test mode."""
    from rich.console import Console
    from rich.table import Table

    from carcheck.pipeline.preprocessor import validate_photos_dir, preprocess_image
    from carcheck.pipeline.yolo_detector import YOLODetector
    from carcheck.pipeline.image_annotator import annotate_image

    console = Console()
    console.print("[bold]CarCheck — YOLO Detection Only[/bold]\n")

    image_paths = validate_photos_dir(photos_dir)
    console.print(f"Found {len(image_paths)} photos")

    processed_dir = photos_dir / "_processed"
    processed = [preprocess_image(p, processed_dir) for p in image_paths]

    detector = YOLODetector()
    results = detector.detect(processed)

    annotated_dir = photos_dir / "_annotated"
    for path, dets in zip(processed, results):
        annotate_image(path, dets, annotated_dir)

    table = Table(title="Detection Results")
    table.add_column("Image", style="cyan")
    table.add_column("Class", style="bold")
    table.add_column("Arabic", style="bold")
    table.add_column("Confidence")
    table.add_column("Severity")

    for path, dets in zip(image_paths, results):
        for d in dets:
            sev_color = "red" if d.severity.value == "major" else "yellow"
            table.add_row(
                path.name, d.class_name, d.class_name_ar,
                f"{d.confidence:.0%}",
                f"[{sev_color}]{d.severity.value}[/{sev_color}]",
            )

    console.print(table)
    console.print(f"\nAnnotated photos saved to: {annotated_dir}")


@app.command()
def create_key(
    name: str = typer.Argument(..., help="Name for the API key (e.g., 'Ahmed - beta tester')"),
) -> None:
    """Create a new API key for a beta tester."""
    import asyncio
    import secrets
    from carcheck.api.database import Database

    key = secrets.token_urlsafe(32)
    db = Database("data/carcheck.db")

    async def _create():
        await db.init()
        await db.create_api_key(key, name)
        await db.close()

    asyncio.run(_create())
    print(f"API key created for '{name}':")
    print(f"  {key}")


if __name__ == "__main__":
    app()
