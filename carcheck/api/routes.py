"""FastAPI route handlers for the inspection API."""
import io
import json
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from fastapi.responses import FileResponse
from PIL import Image, ImageOps

from carcheck.api.auth import require_api_key
from carcheck.api.schemas import (
    CreateInspectionRequest,
    CreateInspectionResponse,
    InspectionStatusResponse,
    PhotoUploadResponse,
    RunInspectionResponse,
)
from carcheck.api.worker import run_inspection

router = APIRouter(prefix="/api/v1", tags=["inspections"])

DATA_DIR = Path("data/inspections")


@router.post("/inspections", response_model=CreateInspectionResponse, status_code=201)
async def create_inspection(
    request: Request,
    body: CreateInspectionRequest,
    api_key: str = Depends(require_api_key),
):
    db = request.app.state.db
    inspection_id = await db.create_inspection(
        api_key=api_key, car_model=body.car_model,
        year=body.year, mileage=body.mileage,
        lang=body.lang, region=body.region,
    )
    photos_dir = DATA_DIR / inspection_id / "photos"
    photos_dir.mkdir(parents=True, exist_ok=True)
    return CreateInspectionResponse(id=inspection_id, status="created")


@router.post("/inspections/{inspection_id}/photos", response_model=PhotoUploadResponse)
async def upload_photo(
    request: Request,
    inspection_id: str,
    file: UploadFile = File(...),
    api_key: str = Depends(require_api_key),
):
    db = request.app.state.db
    inspection = await db.get_inspection(inspection_id, api_key)
    if inspection is None:
        raise HTTPException(status_code=404, detail="Inspection not found")
    if inspection["status"] not in ("created", "uploading"):
        raise HTTPException(status_code=409, detail="Cannot upload photos in current state")

    contents = await file.read()
    if len(contents) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large (max 10MB)")

    try:
        img = Image.open(io.BytesIO(contents))
        img.verify()
        img = Image.open(io.BytesIO(contents))
        if max(img.size) < 640:
            raise HTTPException(status_code=400, detail=f"Image too small ({img.size[0]}x{img.size[1]}). Min 640px")
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image file")

    photo_number = inspection["photo_count"] + 1
    photos_dir = DATA_DIR / inspection_id / "photos"
    photos_dir.mkdir(parents=True, exist_ok=True)
    photo_path = photos_dir / f"photo_{photo_number:03d}.jpg"

    img = Image.open(io.BytesIO(contents))
    img = ImageOps.exif_transpose(img)  # Fix rotation BEFORE stripping EXIF
    img = img.convert("RGB")
    img.save(photo_path, "JPEG", quality=85)

    await db.increment_photo_count(inspection_id)

    return PhotoUploadResponse(photo_number=photo_number, total=photo_number, status="uploading")


@router.post("/inspections/{inspection_id}/run", response_model=RunInspectionResponse, status_code=202)
async def trigger_inspection(
    request: Request,
    inspection_id: str,
    api_key: str = Depends(require_api_key),
):
    db = request.app.state.db
    inspection = await db.get_inspection(inspection_id, api_key)
    if inspection is None:
        raise HTTPException(status_code=404, detail="Inspection not found")
    if inspection["status"] != "uploading":
        raise HTTPException(status_code=409, detail=f"Cannot run inspection in '{inspection['status']}' state. Upload photos first.")
    if inspection["photo_count"] == 0:
        raise HTTPException(status_code=400, detail="No photos uploaded")

    await db.update_status(inspection_id, "processing")
    run_inspection(inspection_id)

    return RunInspectionResponse(id=inspection_id, status="processing")


@router.get("/inspections/{inspection_id}", response_model=InspectionStatusResponse)
async def get_inspection(
    request: Request,
    inspection_id: str,
    api_key: str = Depends(require_api_key),
):
    db = request.app.state.db
    inspection = await db.get_inspection(inspection_id, api_key)
    if inspection is None:
        raise HTTPException(status_code=404, detail="Inspection not found")

    grade = None
    grade_ar = None
    result_data = None

    if inspection["status"] == "completed" and inspection["result_json"]:
        result_data = json.loads(inspection["result_json"])
        inner = result_data.get("نتيجة_الفحص") or result_data.get("inspection_result") or {}
        grade = inner.get("التقييم") or inner.get("grade")
        grade_ar = inner.get("التقييم_بالعربي") or inner.get("grade_ar")

    response = InspectionStatusResponse(
        id=inspection["id"], status=inspection["status"],
        car_model=inspection["car_model"], year=inspection["year"],
        mileage=inspection["mileage"], photo_count=inspection["photo_count"],
        trust_score=inspection["trust_score"],
        grade=grade, grade_ar=grade_ar,
        result=result_data,
        error=inspection["error_message"],
        created_at=inspection["created_at"],
        completed_at=inspection["completed_at"],
    )

    return response


@router.get("/inspections/{inspection_id}/report.pdf")
async def download_report(
    request: Request,
    inspection_id: str,
    api_key: str = Depends(require_api_key),
):
    db = request.app.state.db
    inspection = await db.get_inspection(inspection_id, api_key)
    if inspection is None:
        raise HTTPException(status_code=404, detail="Inspection not found")
    if inspection["status"] != "completed":
        raise HTTPException(status_code=404, detail="Report not ready yet")

    pdf_path = DATA_DIR / inspection_id / "report.pdf"
    if not pdf_path.exists():
        raise HTTPException(status_code=404, detail="PDF report not found")

    return FileResponse(pdf_path, media_type="application/pdf", filename=f"carcheck_{inspection_id[:8]}.pdf")
