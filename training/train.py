"""YOLO11 fine-tuning launcher for car damage detection."""
import argparse
from pathlib import Path


def train(data_yaml: str, weights: str, experiment_name: str, epochs: int = 300, imgsz: int = 1024) -> Path:
    """Run YOLO training with research-backed hyperparameters."""
    from ultralytics import YOLO

    model = YOLO(weights)
    results = model.train(
        data=data_yaml,
        epochs=epochs,
        patience=25,
        imgsz=imgsz,
        batch=4,
        optimizer="AdamW",
        lr0=0.0001,
        lrf=0.01,
        cos_lr=True,
        warmup_epochs=10,     # stabilize early training with larger dataset
        dropout=0.1,
        mixup=0.1,
        multi_scale=True,     # varying resolution per batch — robust to photo distance
        cls=0.3,              # lower class loss — damage types look similar
        dfl=1.7,              # higher DFL — better irregular damage boundaries
        close_mosaic=10,
        project="runs/finetune",
        name=experiment_name,
        exist_ok=True,
        verbose=True,
    )

    best_weights = Path(f"runs/finetune/{experiment_name}/weights/best.pt")
    print(f"\nTraining complete!")
    print(f"Best weights: {best_weights}")
    return best_weights


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Fine-tune YOLO11 for car damage detection")
    parser.add_argument("--data", default="training_data/data.yaml", help="Path to data.yaml")
    parser.add_argument("--weights", required=True, help="Starting weights path or model name")
    parser.add_argument("--name", required=True, help="Experiment name")
    parser.add_argument("--epochs", type=int, default=300, help="Max training epochs")
    parser.add_argument("--imgsz", type=int, default=1024, help="Training image size")
    args = parser.parse_args()
    train(args.data, args.weights, args.name, args.epochs, args.imgsz)
