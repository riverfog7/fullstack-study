from pathlib import Path
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """환경 변수와 .env에서 실행 설정을 읽습니다."""

    model_config = SettingsConfigDict(
        env_prefix="APP_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    env: Literal["development", "production"] = "development"
    database_path: Path = Path("data/tasks.db")
    host: str = "127.0.0.1"
    port: int = Field(default=8000, ge=1, le=65535)
