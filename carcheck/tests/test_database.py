import pytest
import asyncio
from pathlib import Path
from carcheck.api.database import Database


@pytest.fixture
def db(tmp_path):
    database = Database(tmp_path / "test.db")
    asyncio.get_event_loop().run_until_complete(database.init())
    yield database
    asyncio.get_event_loop().run_until_complete(database.close())


def _run(coro):
    return asyncio.get_event_loop().run_until_complete(coro)


def test_create_api_key(db):
    _run(db.create_api_key("test-key-123", "Test User"))
    key = _run(db.validate_api_key("test-key-123"))
    assert key is not None
    assert key["name"] == "Test User"


def test_validate_invalid_api_key(db):
    key = _run(db.validate_api_key("nonexistent"))
    assert key is None


def test_validate_inactive_api_key(db):
    _run(db.create_api_key("inactive-key", "Inactive"))
    _run(db.deactivate_api_key("inactive-key"))
    key = _run(db.validate_api_key("inactive-key"))
    assert key is None


def test_create_inspection(db):
    _run(db.create_api_key("key1", "User1"))
    inspection_id = _run(db.create_inspection(api_key="key1", car_model="Nissan Sunny", year=2019, mileage=85000, lang="ar", region="cairo"))
    assert inspection_id is not None
    inspection = _run(db.get_inspection(inspection_id, "key1"))
    assert inspection["car_model"] == "Nissan Sunny"
    assert inspection["status"] == "created"


def test_get_inspection_wrong_key(db):
    _run(db.create_api_key("key1", "User1"))
    _run(db.create_api_key("key2", "User2"))
    inspection_id = _run(db.create_inspection(api_key="key1", car_model="Nissan Sunny", year=2019, mileage=85000))
    result = _run(db.get_inspection(inspection_id, "key2"))
    assert result is None


def test_update_photo_count(db):
    _run(db.create_api_key("key1", "User1"))
    iid = _run(db.create_inspection(api_key="key1", car_model="Test", year=2020, mileage=50000))
    _run(db.increment_photo_count(iid))
    _run(db.increment_photo_count(iid))
    inspection = _run(db.get_inspection(iid, "key1"))
    assert inspection["photo_count"] == 2
    assert inspection["status"] == "uploading"


def test_update_status(db):
    _run(db.create_api_key("key1", "User1"))
    iid = _run(db.create_inspection(api_key="key1", car_model="Test", year=2020, mileage=50000))
    _run(db.update_status(iid, "processing"))
    inspection = _run(db.get_inspection(iid, "key1"))
    assert inspection["status"] == "processing"


def test_complete_inspection(db):
    _run(db.create_api_key("key1", "User1"))
    iid = _run(db.create_inspection(api_key="key1", car_model="Test", year=2020, mileage=50000))
    _run(db.complete_inspection(iid, trust_score=85, result_json='{"test": true}'))
    inspection = _run(db.get_inspection(iid, "key1"))
    assert inspection["status"] == "completed"
    assert inspection["trust_score"] == 85
    assert inspection["completed_at"] is not None


def test_fail_inspection(db):
    _run(db.create_api_key("key1", "User1"))
    iid = _run(db.create_inspection(api_key="key1", car_model="Test", year=2020, mileage=50000))
    _run(db.fail_inspection(iid, "VLM timeout"))
    inspection = _run(db.get_inspection(iid, "key1"))
    assert inspection["status"] == "failed"
    assert inspection["error_message"] == "VLM timeout"
