from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from carcheck.models import Detection, Severity

# Color map: class_name -> (R, G, B)
_COLORS = {
    "dent": (255, 100, 100),
    "scratch": (255, 200, 50),
    "crack": (255, 50, 50),
    "glass_shatter": (200, 50, 255),
    "lamp_broken": (50, 150, 255),
    "tire_flat": (255, 150, 0),
}

_DEFAULT_COLOR = (255, 100, 100)


def annotate_image(
    image_path: Path,
    detections: list[Detection],
    output_dir: Path,
) -> Path:
    """Draw detection bounding boxes and labels onto an image copy."""
    output_dir.mkdir(parents=True, exist_ok=True)
    img = Image.open(image_path).convert("RGB")
    draw = ImageDraw.Draw(img, "RGBA")

    for det in detections:
        color = _COLORS.get(det.class_name, _DEFAULT_COLOR)
        x1, y1, x2, y2 = det.bbox

        # Semi-transparent fill
        fill_color = (*color, 50)
        draw.rectangle([x1, y1, x2, y2], fill=fill_color, outline=color, width=3)

        # Label
        sev = "⚠" if det.severity == Severity.MAJOR else "•"
        label = f"{sev} {det.class_name_ar} ({det.confidence:.0%})"
        draw.text((x1 + 4, y1 + 4), label, fill=color)

    out_path = output_dir / f"{image_path.stem}_annotated.jpg"
    img.save(out_path, "JPEG", quality=90)
    return out_path
