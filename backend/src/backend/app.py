from contextlib import asynccontextmanager

from fastapi import FastAPI

from backend.core.database import initialize_database
from backend.routers import tasks
from backend.settings import Settings


@asynccontextmanager
async def lifespan(app: FastAPI):
    initialize_database(app.state.settings.database_path)
    yield


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings if settings is not None else Settings()
    production = settings.env == "production"

    app = FastAPI(
        title="할 일 API",
        lifespan=lifespan,
        docs_url=None if production else "/docs",
        redoc_url=None if production else "/redoc",
        openapi_url=None if production else "/openapi.json",
    )
    app.state.settings = settings
    app.include_router(tasks.router)

    @app.get("/api/health", tags=["health"])
    def health() -> dict[str, str]:
        return {"status": "ok"}

    return app
