"""Data pipeline: dedup, remap, filter, split for YOLO fine-tuning."""
from pathlib import Path
import imagehash
from PIL import Image
from training.remap_config import DATASET_REMAPS, remap_class_id


def remap_label_file(input_path: Path, output_path: Path, dataset_name: str) -> bool:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    remapped_lines = []
    for line in input_path.read_text().strip().split("\n"):
        if not line.strip():
            continue
        parts = line.strip().split()
        original_id = int(parts[0])
        new_id = remap_class_id(dataset_name, original_id)
        if new_id is not None:
            remapped_lines.append(f"{new_id} {' '.join(parts[1:])}")
    output_path.write_text("\n".join(remapped_lines) + "\n" if remapped_lines else "")
    return len(remapped_lines) > 0


def process_dataset(dataset_dir: Path, dataset_name: str, output_dir: Path) -> dict:
    import shutil
    stats = {"images": 0, "with_labels": 0, "background": 0}
    for split in ["train", "valid", "test"]:
        images_dir = dataset_dir / split / "images"
        labels_dir = dataset_dir / split / "labels"
        if not images_dir.exists():
            continue
        out_images = output_dir / "all" / "images"
        out_labels = output_dir / "all" / "labels"
        out_images.mkdir(parents=True, exist_ok=True)
        out_labels.mkdir(parents=True, exist_ok=True)
        prefix = dataset_name.replace("-", "_")[:12]
        for img_path in sorted(images_dir.glob("*")):
            if img_path.suffix.lower() not in {".jpg", ".jpeg", ".png"}:
                continue
            label_path = labels_dir / f"{img_path.stem}.txt"
            new_name = f"{prefix}_{img_path.name}"
            out_img = out_images / new_name
            out_lbl = out_labels / f"{prefix}_{img_path.stem}.txt"
            shutil.copy2(img_path, out_img)
            stats["images"] += 1
            if label_path.exists():
                has_labels = remap_label_file(label_path, out_lbl, dataset_name)
                if has_labels:
                    stats["with_labels"] += 1
                else:
                    stats["background"] += 1
            else:
                out_lbl.write_text("")
                stats["background"] += 1
    return stats


def filter_small_images(image_paths: list[Path], min_dim: int = 400) -> list[Path]:
    kept = []
    for p in image_paths:
        try:
            img = Image.open(p)
            if max(img.size) >= min_dim:
                kept.append(p)
        except Exception:
            pass
    return kept


def compute_image_hash(image_path: Path) -> str:
    img = Image.open(image_path)
    return str(imagehash.colorhash(img))


def deduplicate_images(image_paths: list[Path], threshold: int = 5) -> list[Path]:
    seen_hashes: list[imagehash.ImageHash] = []
    unique: list[Path] = []
    for p in image_paths:
        h = imagehash.colorhash(Image.open(p))
        is_dup = False
        for existing_hash in seen_hashes:
            if h - existing_hash < threshold:
                is_dup = True
                break
        if not is_dup:
            seen_hashes.append(h)
            unique.append(p)
    return unique
