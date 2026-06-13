from fastapi import Depends, FastAPI
from fastapi.responses import JSONResponse
from .core.config import AppConfig
from .api.routes.ai_routes import router as ai_router
import logging

logger = logging.getLogger("backend")
logger.setLevel(logging.INFO)
handler = logging.StreamHandler()
formatter = logging.Formatter(
    "%(asctime)s %(levelname)s [%(name)s] %(message)s"
)
handler.setFormatter(formatter)
logger.addHandler(handler)

app = FastAPI(
    title="Cinematic Editor Backend",
    version="0.1.0",
    description="Backend foundation for cinematic editor services.",
)

app.include_router(ai_router)


def get_config() -> AppConfig:
    return AppConfig()


@app.on_event("startup")
async def on_startup() -> None:
    logger.info("Starting backend application")


@app.on_event("shutdown")
async def on_shutdown() -> None:
    logger.info("Shutting down backend application")


@app.get("/health", response_class=JSONResponse)
async def health(config: AppConfig = Depends(get_config)) -> JSONResponse:
    logger.info("Health check request received")
    return JSONResponse(
        status_code=200,
        content={
            "status": "ok",
            "service": config.service_name,
            "version": config.version,
        },
    )
