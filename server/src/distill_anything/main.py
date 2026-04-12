"""FastAPI application entry point."""

import asyncio
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI

from .api.events import router as events_router
from .api.health import router as health_router
from .api.knowledge_base import router as kb_router
from .services.database import init_db
from .services.processing_worker import ProcessingWorker

worker = ProcessingWorker()


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    await init_db()
    # Start processing worker in background
    task = asyncio.create_task(worker.start())
    yield
    worker.stop()
    task.cancel()


app = FastAPI(
    title="Distill Anything Server",
    description="Personal Context Management — event ingestion and knowledge base generation",
    version="0.1.0",
    lifespan=lifespan,
)

app.include_router(health_router, prefix="/api")
app.include_router(events_router, prefix="/api")
app.include_router(kb_router, prefix="/api")


def main() -> None:
    uvicorn.run(
        "distill_anything.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )


if __name__ == "__main__":
    main()
