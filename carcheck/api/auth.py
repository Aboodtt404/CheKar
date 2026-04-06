"""API key authentication dependency for FastAPI."""
from fastapi import Header, HTTPException, Request


async def require_api_key(
    request: Request,
    x_api_key: str = Header(..., description="API key for authentication"),
) -> str:
    db = request.app.state.db
    key_record = await db.validate_api_key(x_api_key)
    if key_record is None:
        raise HTTPException(status_code=401, detail="Invalid or inactive API key")
    return x_api_key
