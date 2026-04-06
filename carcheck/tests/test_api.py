"""API endpoint tests using FastAPI TestClient."""
import asyncio
import io
import pytest
from pathlib import Path
from unittest.mock import patch
from PIL import Image

from fastapi.testclient import TestClient
from carcheck.api.main import app
from carcheck.api.database import Database


@pytest.fixture(autouse=True)
def setup_db(tmp_path, monkeypatch):
    db_path = tmp_path / "test.db"
    data_dir = tmp_path / "data" / "inspections"
    data_dir.mkdir(parents=True)
    monkeypatch.setattr("carcheck.api.routes.DATA_DIR", data_dir)

    db = Database(db_path)
    asyncio.get_event_loop().run_until_complete(db.init())
    asyncio.get_event_loop().run_until_complete(db.create_api_key("test-key", "Test User"))
    app.state.db = db
    yield db
    asyncio.get_event_loop().run_until_complete(db.close())


@pytest.fixture
def client():
    return TestClient(app, raise_server_exceptions=False)


HEADERS = {"X-API-Key": "test-key"}


def _make_test_image(width=800, height=600) -> io.BytesIO:
    img = Image.new("RGB", (width, height), (128, 128, 128))
    buf = io.BytesIO()
    img.save(buf, "JPEG")
    buf.seek(0)
    return buf


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_create_inspection(client):
    r = client.post("/api/v1/inspections", json={
        "car_model": "Nissan Sunny", "year": 2019, "mileage": 85000,
    }, headers=HEADERS)
    assert r.status_code == 201
    data = r.json()
    assert data["status"] == "created"
    assert "id" in data


def test_create_inspection_no_auth(client):
    r = client.post("/api/v1/inspections", json={
        "car_model": "Nissan Sunny", "year": 2019, "mileage": 85000,
    })
    assert r.status_code == 422


def test_create_inspection_bad_auth(client):
    r = client.post("/api/v1/inspections", json={
        "car_model": "Nissan Sunny", "year": 2019, "mileage": 85000,
    }, headers={"X-API-Key": "wrong-key"})
    assert r.status_code == 401


def test_upload_photo(client):
    r = client.post("/api/v1/inspections", json={
        "car_model": "Test", "year": 2020, "mileage": 50000,
    }, headers=HEADERS)
    iid = r.json()["id"]

    img = _make_test_image()
    r = client.post(
        f"/api/v1/inspections/{iid}/photos",
        files={"file": ("photo.jpg", img, "image/jpeg")},
        headers=HEADERS,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["photo_number"] == 1
    assert data["status"] == "uploading"


def test_upload_photo_too_small(client):
    r = client.post("/api/v1/inspections", json={
        "car_model": "Test", "year": 2020, "mileage": 50000,
    }, headers=HEADERS)
    iid = r.json()["id"]

    img = _make_test_image(320, 240)
    r = client.post(
        f"/api/v1/inspections/{iid}/photos",
        files={"file": ("photo.jpg", img, "image/jpeg")},
        headers=HEADERS,
    )
    assert r.status_code == 400
    assert "too small" in r.json()["detail"]


def test_upload_photo_wrong_inspection(client):
    img = _make_test_image()
    r = client.post(
        "/api/v1/inspections/nonexistent/photos",
        files={"file": ("photo.jpg", img, "image/jpeg")},
        headers=HEADERS,
    )
    assert r.status_code == 404


@patch("carcheck.api.routes.run_inspection")
def test_trigger_inspection(mock_run, client):
    r = client.post("/api/v1/inspections", json={
        "car_model": "Test", "year": 2020, "mileage": 50000,
    }, headers=HEADERS)
    iid = r.json()["id"]

    img = _make_test_image()
    client.post(f"/api/v1/inspections/{iid}/photos",
        files={"file": ("photo.jpg", img, "image/jpeg")}, headers=HEADERS)

    r = client.post(f"/api/v1/inspections/{iid}/run", headers=HEADERS)
    assert r.status_code == 202
    assert r.json()["status"] == "processing"
    mock_run.assert_called_once_with(iid)


@patch("carcheck.api.routes.run_inspection")
def test_trigger_no_photos(mock_run, client):
    r = client.post("/api/v1/inspections", json={
        "car_model": "Test", "year": 2020, "mileage": 50000,
    }, headers=HEADERS)
    iid = r.json()["id"]

    r = client.post(f"/api/v1/inspections/{iid}/run", headers=HEADERS)
    assert r.status_code == 409


def test_get_inspection(client):
    r = client.post("/api/v1/inspections", json={
        "car_model": "Nissan Sunny", "year": 2019, "mileage": 85000,
    }, headers=HEADERS)
    iid = r.json()["id"]

    r = client.get(f"/api/v1/inspections/{iid}", headers=HEADERS)
    assert r.status_code == 200
    data = r.json()
    assert data["car_model"] == "Nissan Sunny"
    assert data["status"] == "created"


def test_get_inspection_not_found(client):
    r = client.get("/api/v1/inspections/nonexistent", headers=HEADERS)
    assert r.status_code == 404


def test_download_report_not_ready(client):
    r = client.post("/api/v1/inspections", json={
        "car_model": "Test", "year": 2020, "mileage": 50000,
    }, headers=HEADERS)
    iid = r.json()["id"]

    r = client.get(f"/api/v1/inspections/{iid}/report.pdf", headers=HEADERS)
    assert r.status_code == 404
