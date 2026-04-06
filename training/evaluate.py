"""Evaluate fine-tuned YOLO model on test set and hires photos."""
import argparse
import json
from pathlib import Path
from training.remap_config import CARDD_CLASSES


def evaluate_test_set(weights: str, data_yaml: str) -> dict:
    """Run YOLO val on the test split."""
    from ultralytics import YOLO

    model = YOLO(weights)
    results = model.val(data=data_yaml, split="test", verbose=True)

    metrics = {
        "mAP50": float(results.box.map50),
        "mAP50_95": float(results.box.map),
        "per_class_mAP50": {},
    }

    for cls_id, name in CARDD_CLASSES.items():
        if cls_id < len(results.box.ap50):
            metrics["per_class_mAP50"][name] = float(results.box.ap50[cls_id])

    return metrics


def evaluate_hires_photos(weights: str, photos_dir: str) -> list[dict]:
    """Run inference on hires test photos and report detections."""
    from ultralytics import YOLO

    model = YOLO(weights)
    photos = sorted(Path(photos_dir).glob("*.jpg"))

    results_list = []
    for photo in photos:
        results = model(str(photo), conf=0.25, iou=0.45, imgsz=1024, device="cpu", verbose=False)

        detections = []
        for r in results:
            if len(r.boxes.cls) == 0:
                continue
            for i in range(len(r.boxes.cls)):
                cls_id = int(r.boxes.cls[i])
                cls_name = CARDD_CLASSES.get(cls_id, f"class_{cls_id}")
                conf = float(r.boxes.conf[i])
                detections.append({"class": cls_name, "confidence": f"{conf:.0%}"})

        results_list.append({
            "photo": photo.name,
            "detections": detections if detections else "NO DETECTIONS",
        })

    return results_list


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Evaluate fine-tuned YOLO model")
    parser.add_argument("--weights", required=True, help="Path to best.pt weights")
    parser.add_argument("--data", default="training_data/data.yaml", help="Path to data.yaml")
    parser.add_argument("--hires-dir", default="test_hires/data", help="Path to hires test photos")
    args = parser.parse_args()

    print("=" * 60)
    print("Evaluating on test set...")
    print("=" * 60)
    metrics = evaluate_test_set(args.weights, args.data)
    print(f"\nmAP50: {metrics['mAP50']:.3f}")
    print(f"mAP50-95: {metrics['mAP50_95']:.3f}")
    print("\nPer-class mAP50:")
    for name, score in metrics["per_class_mAP50"].items():
        print(f"  {name}: {score:.3f}")

    print("\n" + "=" * 60)
    print("Evaluating on hires photos...")
    print("=" * 60)
    hires_results = evaluate_hires_photos(args.weights, args.hires_dir)
    for r in hires_results:
        print(f"\n{r['photo']}:")
        if isinstance(r["detections"], str):
            print(f"  {r['detections']}")
        else:
            for d in r["detections"]:
                print(f"  {d['class']} ({d['confidence']})")

    output = {"test_metrics": metrics, "hires_results": hires_results}
    output_path = Path(args.weights).parent / "evaluation_results.json"
    output_path.write_text(json.dumps(output, indent=2, ensure_ascii=False))
    print(f"\nResults saved to: {output_path}")
