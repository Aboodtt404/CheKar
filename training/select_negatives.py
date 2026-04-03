"""Select hard negative images from car-parts dataset for training."""
import random
import shutil
from pathlib import Path
from training.remap_config import LIGHT_PART_CLASSES, GLASS_PART_CLASSES


def _image_has_parts(label_path, class_names, target_names):
    if not label_path.exists():
        return False
    for line in label_path.read_text().strip().split("\n"):
        if not line.strip():
            continue
        cls_id = int(line.strip().split()[0])
        if cls_id < len(class_names) and class_names[cls_id] in target_names:
            return True
    return False


def select_hard_negatives(dataset_dir, output_dir, class_names, max_total=500):
    out_images = output_dir / "all" / "images"
    out_labels = output_dir / "all" / "labels"
    out_images.mkdir(parents=True, exist_ok=True)
    out_labels.mkdir(parents=True, exist_ok=True)
    light_images, glass_images, other_images = [], [], []
    for split in ["train", "valid", "test"]:
        images_dir = dataset_dir / split / "images"
        labels_dir = dataset_dir / split / "labels"
        if not images_dir.exists():
            continue
        for img_path in sorted(images_dir.glob("*")):
            if img_path.suffix.lower() not in {".jpg", ".jpeg", ".png"}:
                continue
            label_path = labels_dir / f"{img_path.stem}.txt"
            if _image_has_parts(label_path, class_names, LIGHT_PART_CLASSES):
                light_images.append(img_path)
            elif _image_has_parts(label_path, class_names, GLASS_PART_CLASSES):
                glass_images.append(img_path)
            else:
                other_images.append(img_path)
    selected = []
    selected.extend(light_images[:200])
    remaining = max_total - len(selected)
    selected.extend(glass_images[:min(100, remaining)])
    remaining = max_total - len(selected)
    if remaining > 0:
        random.seed(42)
        random.shuffle(other_images)
        selected.extend(other_images[:remaining])
    for img_path in selected:
        new_name = f"neg_{img_path.name}"
        shutil.copy2(img_path, out_images / new_name)
        (out_labels / f"neg_{img_path.stem}.txt").write_text("")
    return len(selected)
