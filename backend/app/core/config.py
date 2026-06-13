from pydantic import BaseSettings


class AppConfig(BaseSettings):
    service_name: str = "cinematic-editor-backend"
    version: str = "0.1.0"
    environment: str = "development"
    log_level: str = "INFO"

    class Config:
        env_prefix = "APP_"
        case_sensitive = False
