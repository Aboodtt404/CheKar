"""SQLite database for inspections and API keys."""
import uuid
from datetime import datetime, timezone
from pathlib import Path
import aiosqlite


class Database:
    def __init__(self, db_path: Path | str = "data/carcheck.db"):
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._conn: aiosqlite.Connection | None = None

    async def init(self):
        self._conn = await aiosqlite.connect(self.db_path)
        self._conn.row_factory = aiosqlite.Row
        await self._conn.execute("PRAGMA journal_mode=WAL")
        await self._conn.execute("PRAGMA busy_timeout=5000")
        await self._create_tables()

    async def close(self):
        if self._conn:
            await self._conn.close()

    async def _create_tables(self):
        await self._conn.executescript("""
            CREATE TABLE IF NOT EXISTS api_keys (
                key TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                is_active BOOLEAN DEFAULT 1
            );
            CREATE TABLE IF NOT EXISTS inspections (
                id TEXT PRIMARY KEY,
                api_key TEXT NOT NULL REFERENCES api_keys(key),
                status TEXT NOT NULL DEFAULT 'created',
                car_model TEXT NOT NULL,
                year INTEGER NOT NULL,
                mileage INTEGER NOT NULL,
                lang TEXT DEFAULT 'ar',
                region TEXT DEFAULT 'cairo',
                photo_count INTEGER DEFAULT 0,
                trust_score INTEGER,
                result_json TEXT,
                error_message TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                completed_at TIMESTAMP
            );
        """)
        await self._conn.commit()

    async def create_api_key(self, key: str, name: str):
        await self._conn.execute("INSERT INTO api_keys (key, name) VALUES (?, ?)", (key, name))
        await self._conn.commit()

    async def validate_api_key(self, key: str) -> dict | None:
        cursor = await self._conn.execute("SELECT * FROM api_keys WHERE key = ? AND is_active = 1", (key,))
        row = await cursor.fetchone()
        return dict(row) if row else None

    async def deactivate_api_key(self, key: str):
        await self._conn.execute("UPDATE api_keys SET is_active = 0 WHERE key = ?", (key,))
        await self._conn.commit()

    async def create_inspection(self, api_key: str, car_model: str, year: int, mileage: int, lang: str = "ar", region: str = "cairo") -> str:
        inspection_id = str(uuid.uuid4())
        await self._conn.execute(
            "INSERT INTO inspections (id, api_key, car_model, year, mileage, lang, region) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (inspection_id, api_key, car_model, year, mileage, lang, region),
        )
        await self._conn.commit()
        return inspection_id

    async def get_inspection(self, inspection_id: str, api_key: str) -> dict | None:
        cursor = await self._conn.execute("SELECT * FROM inspections WHERE id = ? AND api_key = ?", (inspection_id, api_key))
        row = await cursor.fetchone()
        return dict(row) if row else None

    async def get_inspection_by_id(self, inspection_id: str) -> dict | None:
        cursor = await self._conn.execute("SELECT * FROM inspections WHERE id = ?", (inspection_id,))
        row = await cursor.fetchone()
        return dict(row) if row else None

    async def increment_photo_count(self, inspection_id: str):
        await self._conn.execute("UPDATE inspections SET photo_count = photo_count + 1, status = 'uploading' WHERE id = ?", (inspection_id,))
        await self._conn.commit()

    async def update_status(self, inspection_id: str, status: str):
        await self._conn.execute("UPDATE inspections SET status = ? WHERE id = ?", (status, inspection_id))
        await self._conn.commit()

    async def complete_inspection(self, inspection_id: str, trust_score: int, result_json: str):
        now = datetime.now(timezone.utc).isoformat()
        await self._conn.execute(
            "UPDATE inspections SET status = 'completed', trust_score = ?, result_json = ?, completed_at = ? WHERE id = ?",
            (trust_score, result_json, now, inspection_id),
        )
        await self._conn.commit()

    async def fail_inspection(self, inspection_id: str, error_message: str):
        await self._conn.execute("UPDATE inspections SET status = 'failed', error_message = ? WHERE id = ?", (error_message, inspection_id))
        await self._conn.commit()
