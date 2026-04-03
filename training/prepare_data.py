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
