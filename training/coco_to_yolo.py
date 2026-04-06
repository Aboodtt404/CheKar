"""Convert VIA or COCO format annotations to YOLO format."""
import json
from pathlib import Path
from PIL import Image as PILImage


# VehiDE class names (Vietnamese) → 0-indexed IDs for YOLO
VEHIDE_CLASS_TO_ID = {
    "be_den": 0,       # broken lights
    "mat_bo_phan": 1,  # lost parts
    "mop_lom": 2,      # dents
    "rach": 3,         # torn
    "thung": 4,        # punctured
    "tray_son": 5,     # scratches
    "vo_kinh": 6,      # broken glass
}


def via_to_yolo(
    via_json_path: Path,
    images_dir: Path,
    output_images_dir: Path,
    output_labels_dir: Path,
) -> dict:
    """Convert VIA (VGG Image Annotator) annotations to YOLO seg format.

    VIA format: dict of {filename: {name, regions: [{all_x, all_y, class}]}}
    YOLO seg format: class_id x1 y1 x2 y2 ... (normalized polygon coords)
    """
    import shutil

    output_images_dir.mkdir(parents=True, exist_ok=True)
    output_labels_dir.mkdir(parents=True, exist_ok=True)

    with open(via_json_path, "r") as f:
        data = json.load(f)

    stats = {"images": 0, "annotations": 0, "skipped_no_file": 0, "skipped_bad_poly": 0}

    for filename, entry in data.items():
        img_name = entry.get("name", filename)
        src_path = images_dir / img_name
        if not src_path.exists():
            stats["skipped_no_file"] += 1
            continue

        # Get image dimensions for normalization
        try:
            img = PILImage.open(src_path)
            img_w, img_h = img.size
        except Exception:
            stats["skipped_no_file"] += 1
            continue

        # Copy image
        dest_img = output_images_dir / img_name
        if not dest_img.exists():
            shutil.copy2(src_path, dest_img)

        # Convert regions to YOLO label lines
        lines = []
        for region in entry.get("regions", []):
            cls_name = region.get("class", "")
            cls_id = VEHIDE_CLASS_TO_ID.get(cls_name)
            if cls_id is None:
                continue

            all_x = region.get("all_x", [])
            all_y = region.get("all_y", [])

            if len(all_x) < 3 or len(all_x) != len(all_y):
                stats["skipped_bad_poly"] += 1
                continue

            # Normalize polygon coordinates
            normalized = []
            for x, y in zip(all_x, all_y):
                nx = max(0.0, min(1.0, x / img_w))
                ny = max(0.0, min(1.0, y / img_h))
                normalized.extend([nx, ny])

            coords_str = " ".join(f"{v:.6f}" for v in normalized)
            lines.append(f"{cls_id} {coords_str}")
            stats["annotations"] += 1

        # Write label file (empty if no valid regions)
        label_path = output_labels_dir / f"{Path(img_name).stem}.txt"
        label_path.write_text("\n".join(lines) + "\n" if lines else "")
        stats["images"] += 1

    return stats


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 4:
        print("Usage: python coco_to_yolo.py <via_annotations.json> <images_dir> <output_dir>")
        sys.exit(1)

    via_json = Path(sys.argv[1])
    images = Path(sys.argv[2])
    output = Path(sys.argv[3])

    stats = via_to_yolo(
        via_json, images,
        output / "images", output / "labels",
    )
    print(f"Converted: {stats['images']} images, {stats['annotations']} annotations")
    if stats["skipped_no_file"] > 0:
        print(f"Skipped (missing files): {stats['skipped_no_file']}")
    if stats["skipped_bad_poly"] > 0:
        print(f"Skipped (bad polygons): {stats['skipped_bad_poly']}")
