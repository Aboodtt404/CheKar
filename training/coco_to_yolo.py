"""Convert COCO-format annotations to YOLO format (detection or segmentation)."""
import json
from pathlib import Path


def coco_to_yolo(
    coco_json_path: Path,
    images_dir: Path,
    output_images_dir: Path,
    output_labels_dir: Path,
    use_segmentation: bool = True,
) -> dict:
    """Convert COCO annotations to YOLO label files.

    Args:
        coco_json_path: Path to COCO annotations JSON.
        images_dir: Directory containing the source images.
        output_images_dir: Where to symlink/copy images.
        output_labels_dir: Where to write YOLO label .txt files.
        use_segmentation: If True, output polygon masks (for seg training).
                          If False, output bounding boxes only.

    Returns:
        Stats dict with image and annotation counts.
    """
    import shutil

    output_images_dir.mkdir(parents=True, exist_ok=True)
    output_labels_dir.mkdir(parents=True, exist_ok=True)

    with open(coco_json_path, "r") as f:
        coco = json.load(f)

    # Build lookup: image_id → image info
    id_to_image = {img["id"]: img for img in coco["images"]}

    # Build lookup: image_id → list of annotations
    image_annotations: dict[int, list] = {}
    for ann in coco["annotations"]:
        img_id = ann["image_id"]
        if img_id not in image_annotations:
            image_annotations[img_id] = []
        image_annotations[img_id].append(ann)

    # COCO category_id → 0-indexed class ID
    # COCO categories are 1-indexed, we need 0-indexed for YOLO
    cat_id_to_idx = {}
    for i, cat in enumerate(sorted(coco["categories"], key=lambda c: c["id"])):
        cat_id_to_idx[cat["id"]] = i

    stats = {"images": 0, "annotations": 0, "skipped_no_file": 0}

    for img_id, img_info in id_to_image.items():
        filename = img_info["file_name"]
        # Handle nested paths in file_name (e.g., "image/image/xxx.jpg")
        src_path = images_dir / filename
        if not src_path.exists():
            # Try just the basename
            src_path = images_dir / Path(filename).name
        if not src_path.exists():
            stats["skipped_no_file"] += 1
            continue

        img_w = img_info["width"]
        img_h = img_info["height"]

        # Copy image
        dest_img = output_images_dir / Path(filename).name
        if not dest_img.exists():
            shutil.copy2(src_path, dest_img)

        # Write YOLO label
        label_path = output_labels_dir / f"{Path(filename).stem}.txt"
        lines = []

        for ann in image_annotations.get(img_id, []):
            cls_idx = cat_id_to_idx.get(ann["category_id"])
            if cls_idx is None:
                continue

            if use_segmentation and ann.get("segmentation"):
                # Polygon segmentation → normalized coords
                seg = ann["segmentation"]
                if isinstance(seg, list) and len(seg) > 0:
                    # Take first polygon (COCO can have multiple)
                    poly = seg[0]
                    if len(poly) < 6:  # need at least 3 points
                        continue
                    # Normalize: [x1, y1, x2, y2, ...] → [x1/w, y1/h, ...]
                    normalized = []
                    for j in range(0, len(poly), 2):
                        nx = poly[j] / img_w
                        ny = poly[j + 1] / img_h
                        # Clamp to [0, 1]
                        nx = max(0.0, min(1.0, nx))
                        ny = max(0.0, min(1.0, ny))
                        normalized.extend([nx, ny])
                    coords_str = " ".join(f"{v:.6f}" for v in normalized)
                    lines.append(f"{cls_idx} {coords_str}")
                    stats["annotations"] += 1
            else:
                # Bounding box → YOLO format (cx, cy, w, h normalized)
                bbox = ann.get("bbox")
                if bbox is None or len(bbox) != 4:
                    continue
                bx, by, bw, bh = bbox
                cx = (bx + bw / 2) / img_w
                cy = (by + bh / 2) / img_h
                nw = bw / img_w
                nh = bh / img_h
                # Clamp
                cx = max(0.0, min(1.0, cx))
                cy = max(0.0, min(1.0, cy))
                nw = max(0.0, min(1.0, nw))
                nh = max(0.0, min(1.0, nh))
                lines.append(f"{cls_idx} {cx:.6f} {cy:.6f} {nw:.6f} {nh:.6f}")
                stats["annotations"] += 1

        label_path.write_text("\n".join(lines) + "\n" if lines else "")
        stats["images"] += 1

    return stats


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 4:
        print("Usage: python coco_to_yolo.py <coco.json> <images_dir> <output_dir> [--bbox]")
        sys.exit(1)

    coco_json = Path(sys.argv[1])
    images = Path(sys.argv[2])
    output = Path(sys.argv[3])
    use_seg = "--bbox" not in sys.argv

    stats = coco_to_yolo(
        coco_json, images,
        output / "images", output / "labels",
        use_segmentation=use_seg,
    )
    print(f"Converted: {stats['images']} images, {stats['annotations']} annotations")
    if stats["skipped_no_file"] > 0:
        print(f"Skipped (missing files): {stats['skipped_no_file']}")
