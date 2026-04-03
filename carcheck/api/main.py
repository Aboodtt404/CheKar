"""FastAPI application entry point."""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from carcheck.api.database import Database
from carcheck.api.routes import router


@asynccontextmanager
async def lifespan(app: FastAPI):
    db = Database("data/carcheck.db")
    await db.init()
    app.state.db = db
    yield
    await db.close()


app = FastAPI(
    title="CarCheck API",
    description="AI-powered car inspection for the Egyptian market",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)


@app.get("/health")
async def health():
    return {"status": "ok"}
