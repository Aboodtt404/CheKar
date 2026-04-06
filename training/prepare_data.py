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
    return str(imagehash.phash(img))


def deduplicate_images(image_paths: list[Path], threshold: int = 5) -> list[Path]:
    seen_hashes: list[imagehash.ImageHash] = []
    unique: list[Path] = []
    for p in image_paths:
        h = imagehash.phash(Image.open(p))
        is_dup = False
        for existing_hash in seen_hashes:
            if h - existing_hash < threshold:
                is_dup = True
                break
        if not is_dup:
            seen_hashes.append(h)
            unique.append(p)
    return unique


def create_class_vector(label_path: Path, num_classes: int = 6) -> list[int]:
    vector = [0] * num_classes
    if not label_path.exists():
        return vector
    for line in label_path.read_text().strip().split("\n"):
        if not line.strip():
            continue
        cls_id = int(line.strip().split()[0])
        if cls_id < num_classes:
            vector[cls_id] = 1
    return vector


def stratified_split(merged_dir: Path, output_dir: Path, train_ratio: float = 0.8, val_ratio: float = 0.1) -> dict:
    import numpy as np
    from iterstrat.ml_stratifiers import MultilabelStratifiedShuffleSplit
    import shutil

    images_dir = merged_dir / "all" / "images"
    labels_dir = merged_dir / "all" / "labels"
    image_paths = sorted(p for p in images_dir.glob("*") if p.suffix.lower() in {".jpg", ".jpeg", ".png"})

    vectors = [create_class_vector(labels_dir / f"{p.stem}.txt") for p in image_paths]

    X = np.arange(len(image_paths)).reshape(-1, 1)
    y = np.array(vectors)

    test_ratio = 1.0 - train_ratio - val_ratio
    splitter1 = MultilabelStratifiedShuffleSplit(n_splits=1, test_size=test_ratio, random_state=42)
    trainval_idx, test_idx = next(splitter1.split(X, y))

    val_fraction = val_ratio / (train_ratio + val_ratio)
    splitter2 = MultilabelStratifiedShuffleSplit(n_splits=1, test_size=val_fraction, random_state=42)
    train_sub_idx, val_sub_idx = next(splitter2.split(X[trainval_idx], y[trainval_idx]))
    train_idx = trainval_idx[train_sub_idx]
    val_idx = trainval_idx[val_sub_idx]

    stats = {"train": 0, "val": 0, "test": 0}
    for split_name, indices in [("train", train_idx), ("val", val_idx), ("test", test_idx)]:
        split_imgs = output_dir / split_name / "images"
        split_lbls = output_dir / split_name / "labels"
        split_imgs.mkdir(parents=True, exist_ok=True)
        split_lbls.mkdir(parents=True, exist_ok=True)
        for i in indices:
            img_path = image_paths[i]
            lbl_path = labels_dir / f"{img_path.stem}.txt"
            shutil.copy2(img_path, split_imgs / img_path.name)
            if lbl_path.exists():
                shutil.copy2(lbl_path, split_lbls / lbl_path.name)
            else:
                (split_lbls / f"{img_path.stem}.txt").write_text("")
            stats[split_name] += 1

    yaml_content = f"path: {output_dir}\ntrain: train/images\nval: val/images\ntest: test/images\n\nnames:\n  0: dent\n  1: scratch\n  2: crack\n  3: glass_shatter\n  4: lamp_broken\n  5: tire_flat\n\nnc: 6\n"
    (output_dir / "data.yaml").write_text(yaml_content)
    return stats


def process_vehide(dataset_dir: Path, output_dir: Path) -> dict:
    """Process VehiDE dataset: VIA JSON → YOLO labels → remap to CarDD classes."""
    from training.coco_to_yolo import via_to_yolo
    import shutil

    stats = {"images": 0, "with_labels": 0, "background": 0}
    temp_dir = output_dir / "_vehide_temp"

    # VehiDE uses VIA format (VGG Image Annotator)
    splits = []

    # Train: 0Train_via_annos.json + image/image/
    train_json = dataset_dir / "0Train_via_annos.json"
    train_images = dataset_dir / "image" / "image"
    if not train_images.exists():
        train_images = dataset_dir / "image"
    if train_json.exists():
        splits.append(("train", train_json, train_images))

    # Val: 0Val_via_annos.json + validation/validation/
    val_json = dataset_dir / "0Val_via_annos.json"
    val_images = dataset_dir / "validation" / "validation"
    if not val_images.exists():
        val_images = dataset_dir / "validation"
    if val_json.exists():
        splits.append(("val", val_json, val_images))

    for split_name, json_path, img_dir in splits:
        print(f"    Converting VehiDE {split_name} from VIA to YOLO...")
        temp_split = temp_dir / split_name
        convert_stats = via_to_yolo(
            json_path, img_dir,
            temp_split / "images", temp_split / "labels",
        )
        print(f"    Converted {convert_stats['images']} images, {convert_stats['annotations']} annotations")

    # Remap VehiDE 0-indexed classes to CarDD 6-class standard and merge
    out_images = output_dir / "all" / "images"
    out_labels = output_dir / "all" / "labels"
    out_images.mkdir(parents=True, exist_ok=True)
    out_labels.mkdir(parents=True, exist_ok=True)

    for split_dir in sorted(temp_dir.iterdir()):
        if not split_dir.is_dir():
            continue
        imgs_dir = split_dir / "images"
        lbls_dir = split_dir / "labels"
        if not imgs_dir.exists():
            continue
        for img_path in sorted(imgs_dir.glob("*")):
            if img_path.suffix.lower() not in {".jpg", ".jpeg", ".png"}:
                continue
            label_path = lbls_dir / f"{img_path.stem}.txt"
            new_name = f"vehide_{img_path.name}"
            out_img = out_images / new_name
            out_lbl = out_labels / f"vehide_{img_path.stem}.txt"

            shutil.copy2(img_path, out_img)
            stats["images"] += 1

            if label_path.exists():
                has_labels = remap_label_file(label_path, out_lbl, "vehide")
                if has_labels:
                    stats["with_labels"] += 1
                else:
                    stats["background"] += 1
            else:
                out_lbl.write_text("")
                stats["background"] += 1

    # Clean up temp
    shutil.rmtree(temp_dir, ignore_errors=True)
    return stats


def run_pipeline(datasets_dir: Path, output_dir: Path, max_negatives: int = 500) -> None:
    import yaml
    from training.remap_config import CARDD_CLASSES
    from collections import Counter

    merged_dir = output_dir / "_merged"
    print("=" * 60)
    print("CarCheck YOLO Fine-Tuning Data Pipeline")
    print("=" * 60)

    damage_datasets = {
        "dammage-detection-in-car": datasets_dir / "dammage-detection-in-car",
        "car-damaged-severity-detection": datasets_dir / "car-damaged-severity-detection",
        "car-damage-4-classes": datasets_dir / "car-damage-4-classes",
    }

    for name, path in damage_datasets.items():
        print(f"\nProcessing {name}...")
        stats = process_dataset(path, name, merged_dir)
        print(f"  Images: {stats['images']}, With labels: {stats['with_labels']}, Background: {stats['background']}")

    # Process VehiDE (COCO format — needs conversion)
    vehide_dir = datasets_dir / "vehide"
    if not vehide_dir.exists():
        vehide_dir = datasets_dir / "vehide-dataset"
    if vehide_dir.exists():
        print(f"\nProcessing VehiDE (COCO → YOLO conversion)...")
        stats = process_vehide(vehide_dir, merged_dir)
        print(f"  Images: {stats['images']}, With labels: {stats['with_labels']}, Background: {stats['background']}")
    else:
        print(f"\nVehiDE not found at {datasets_dir}/vehide — skipping")

    print(f"\nSelecting {max_negatives} hard negatives from car-parts...")
    parts_dir = datasets_dir / "car-parts-ulbml"
    parts_yaml = parts_dir / "data.yaml"
    class_names = yaml.safe_load(parts_yaml.read_text())["names"]

    from training.select_negatives import select_hard_negatives
    n_neg = select_hard_negatives(parts_dir, merged_dir, class_names, max_negatives)
    print(f"  Selected {n_neg} hard negative images")

    print("\nFiltering small images (<400px)...")
    all_images = sorted((merged_dir / "all" / "images").glob("*"))
    kept = filter_small_images(all_images, min_dim=400)
    removed = len(all_images) - len(kept)
    print(f"  Removed {removed} small images, kept {len(kept)}")

    kept_stems = {p.stem for p in kept}
    for img in all_images:
        if img.stem not in kept_stems:
            img.unlink()
            lbl = merged_dir / "all" / "labels" / f"{img.stem}.txt"
            if lbl.exists():
                lbl.unlink()

    print("\nDeduplicating images...")
    remaining_images = sorted((merged_dir / "all" / "images").glob("*"))
    unique = deduplicate_images(remaining_images, threshold=5)
    dups = len(remaining_images) - len(unique)
    print(f"  Removed {dups} duplicates, kept {len(unique)}")

    unique_stems = {p.stem for p in unique}
    for img in remaining_images:
        if img.stem not in unique_stems:
            img.unlink()
            lbl = merged_dir / "all" / "labels" / f"{img.stem}.txt"
            if lbl.exists():
                lbl.unlink()

    print("\nSplitting dataset (80/10/10 stratified)...")
    final_dir = output_dir / "training_data"
    stats = stratified_split(merged_dir, final_dir)
    print(f"  Train: {stats['train']}, Val: {stats['val']}, Test: {stats['test']}")

    print("\nClass distribution (train):")
    class_counts = Counter()
    for lbl in sorted((final_dir / "train" / "labels").glob("*.txt")):
        for line in lbl.read_text().strip().split("\n"):
            if line.strip():
                cls_id = int(line.strip().split()[0])
                class_counts[cls_id] += 1
    for cls_id, name in sorted(CARDD_CLASSES.items()):
        print(f"  {name}: {class_counts.get(cls_id, 0)}")

    print(f"\nDataset ready at: {final_dir}")
    print(f"data.yaml: {final_dir / 'data.yaml'}")


if __name__ == "__main__":
    import sys
    datasets_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("quality_check")
    output_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(".")
    run_pipeline(datasets_dir, output_dir)
