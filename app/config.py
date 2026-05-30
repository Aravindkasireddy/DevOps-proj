from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_env: str = "development"
    app_name: str = "fin-enterprise-api"
    log_level: str = "INFO"
    api_host: str = "0.0.0.0"  # nosec B104
    api_port: int = 8000
    database_url: str = "postgresql+asyncpg://finenterprise:fin_enterprise_secret@localhost:5432/fin_enterprise_assets"


@lru_cache
def get_settings() -> Settings:
    return Settings()
