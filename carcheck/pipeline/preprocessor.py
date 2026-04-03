from pathlib import Path

from PIL import Image, UnidentifiedImageError

from carcheck.config import settings

_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def preprocess_image(image_path: Path, output_dir: Path) -> Path:
    """Validate and resize a single image. Returns path to processed image."""
    try:
        img = Image.open(image_path)
        img.verify()
        img = Image.open(image_path)  # reopen after verify
    except (UnidentifiedImageError, Exception) as e:
        raise ValueError(f"{image_path.name} is not a valid image: {e}")

    width, height = img.size
    if max(width, height) < settings.min_image_dimension:
        raise ValueError(
            f"{image_path.name} is too small ({width}x{height}). "
            f"Minimum dimension: {settings.min_image_dimension}px"
        )

    output_dir.mkdir(parents=True, exist_ok=True)

    if max(width, height) > settings.max_image_dimension:
        ratio = settings.max_image_dimension / max(width, height)
        new_size = (int(width * ratio), int(height * ratio))
        img = img.resize(new_size, Image.LANCZOS)

    img = img.convert("RGB")
    out_path = output_dir / f"{image_path.stem}.jpg"
    img.save(out_path, "JPEG", quality=settings.jpeg_quality)
    return out_path


def validate_photos_dir(photos_dir: Path) -> list[Path]:
    """Return sorted list of valid image paths in a directory."""
    if not photos_dir.is_dir():
        raise ValueError(f"{photos_dir} is not a directory")

    paths = sorted(
        p for p in photos_dir.iterdir()
        if p.suffix.lower() in _IMAGE_EXTENSIONS
    )

    if not paths:
        raise ValueError(f"No valid images found in {photos_dir}")

    return paths
