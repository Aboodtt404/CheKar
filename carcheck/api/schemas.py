"""Pydantic models for API request/response validation."""
from pydantic import BaseModel, Field


class CreateInspectionRequest(BaseModel):
    car_model: str = Field(..., min_length=1, examples=["Nissan Sunny"])
    year: int = Field(..., ge=1990, le=2030, examples=[2019])
    mileage: int = Field(..., ge=0, examples=[85000])
    lang: str = Field(default="ar", pattern="^(ar|en)$")
    region: str = Field(default="cairo", examples=["cairo", "alexandria"])


class CreateInspectionResponse(BaseModel):
    id: str
    status: str


class PhotoUploadResponse(BaseModel):
    photo_number: int
    total: int
    status: str


class RunInspectionResponse(BaseModel):
    id: str
    status: str


class InspectionStatusResponse(BaseModel):
    id: str
    status: str
    car_model: str
    year: int
    mileage: int
    photo_count: int
    trust_score: int | None = None  # deprecated, kept for backward compat
    grade: str | None = None
    grade_ar: str | None = None
    result: dict | None = None
    error: str | None = None
    created_at: str
    completed_at: str | None = None


class ErrorResponse(BaseModel):
    detail: str
