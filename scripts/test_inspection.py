"""Quick test: run a full inspection through the pipeline."""
import glob
import json
import time
import requests

BASE = "http://localhost:8090/api/v1"
KEY = "tester-omar-key"
HEADERS = {"X-API-Key": KEY}


def main():
    # Create inspection
    r = requests.post(f"{BASE}/inspections", headers=HEADERS, json={
        "car_model": "Test Toyota", "year": 2020, "mileage": 50000,
    })
    insp = r.json()
    insp_id = insp["id"]
    print(f"Created: {insp_id}")

    # Upload test images — use existing inspection photos or hires test set
    photos = sorted(glob.glob("data/inspections/*/photos/*.jpg"))[:4]
    if not photos:
        photos = sorted(glob.glob("test_results/hires/*.jpg"))[:4]
    print(f"Uploading {len(photos)} photos...")
    for p in photos:
        with open(p, "rb") as f:
            r = requests.post(f"{BASE}/inspections/{insp_id}/photos", headers=HEADERS, files={"file": f})
        print(f"  {p}: {r.status_code}")

    # Trigger
    r = requests.post(f"{BASE}/inspections/{insp_id}/run", headers=HEADERS)
    print(f"Triggered: {r.status_code}")

    # Poll
    for i in range(30):
        time.sleep(10)
        r = requests.get(f"{BASE}/inspections/{insp_id}", headers=HEADERS)
        data = r.json()
        status = data.get("status", "unknown")
        print(f"  Poll {i+1}: {status}")

        if status == "failed":
            print(f"  Error: {data.get('error', 'unknown')}")
            break
        elif status == "completed":
            grade = data.get("grade", "?")
            print(f"  Grade: {grade}")

            result = data.get("result", {})
            report = result.get("نتيجة_الفحص", {})
            findings = report.get("النتائج", [])
            print(f"  Findings: {len(findings)}")
            for f in findings[:5]:
                t = f.get("النوع", "?")
                loc = f.get("الموقع", "?")
                src = f.get("المصدر", "?")
                print(f"    - {t} @ {loc} ({src})")

            categories = report.get("الفئات", {})
            if categories:
                print("  Categories:")
                for cat, val in categories.items():
                    light = val.get("الحالة", "?") if isinstance(val, dict) else val
                    print(f"    {cat}: {light}")
            break


if __name__ == "__main__":
    main()
