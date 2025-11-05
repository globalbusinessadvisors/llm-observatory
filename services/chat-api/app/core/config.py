"""Application configuration using Pydantic settings."""

from typing import List, Optional
from pydantic import Field, PostgresDsn, RedisDsn, validator
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Application
    APP_NAME: str = "LLM Observatory Chat API"
    APP_VERSION: str = "1.0.0"
    ENVIRONMENT: str = Field(default="development", pattern="^(development|staging|production)$")
    DEBUG: bool = False
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    # CORS
    CORS_ORIGINS: List[str] = ["http://localhost:3000", "http://localhost:8080"]
    CORS_CREDENTIALS: bool = True
    CORS_METHODS: List[str] = ["*"]
    CORS_HEADERS: List[str] = ["*"]

    # Database
    DATABASE_URL: PostgresDsn = Field(
        default="postgresql://llm_observatory_app:change_me_in_production@localhost:5432/llm_observatory"
    )
    DB_POOL_SIZE: int = 5
    DB_MAX_OVERFLOW: int = 10
    DB_POOL_TIMEOUT: int = 30
    DB_POOL_RECYCLE: int = 3600
    DB_ECHO: bool = False

    # Redis
    REDIS_URL: RedisDsn = Field(
        default="redis://:redis_password@localhost:6379/0"
    )
    REDIS_CACHE_TTL: int = 3600
    REDIS_SESSION_TTL: int = 86400

    # OpenAI
    OPENAI_API_KEY: str = Field(default="")
    OPENAI_ORG_ID: Optional[str] = None
    OPENAI_DEFAULT_MODEL: str = "gpt-4"
    OPENAI_MAX_RETRIES: int = 3
    OPENAI_TIMEOUT: int = 60

    # Anthropic
    ANTHROPIC_API_KEY: str = Field(default="")
    ANTHROPIC_DEFAULT_MODEL: str = "claude-3-sonnet-20240229"

    # Azure OpenAI
    AZURE_OPENAI_API_KEY: str = Field(default="")
    AZURE_OPENAI_ENDPOINT: Optional[str] = None
    AZURE_OPENAI_API_VERSION: str = "2024-02-01"

    # LLM Configuration
    DEFAULT_PROVIDER: str = "openai"
    MAX_TOKENS: int = 4096
    TEMPERATURE: float = 0.7
    CONTEXT_WINDOW_LIMIT: int = 8000
    ENABLE_STREAMING: bool = True

    # Rate Limiting
    RATE_LIMIT_ENABLED: bool = True
    RATE_LIMIT_REQUESTS: int = 100
    RATE_LIMIT_WINDOW: int = 60

    # Cost Tracking
    TRACK_COSTS: bool = True
    COST_ALERT_THRESHOLD: float = 10.0

    # Observability
    OTLP_COLLECTOR_URL: str = "http://localhost:4318"
    ENABLE_TRACING: bool = True
    ENABLE_METRICS: bool = True
    TRACE_SAMPLE_RATE: float = 1.0

    # Logging
    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "json"
    LOG_FILE: Optional[str] = None

    # Security
    SECRET_KEY: str = Field(default="change_me_to_a_random_secret_key_in_production")
    JWT_SECRET: str = Field(default="change_me_to_a_random_jwt_secret")
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRATION: int = 3600

    # PII Protection
    ENABLE_PII_DETECTION: bool = True
    REDACT_PII: bool = True

    class Config:
        """Pydantic configuration."""
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True

    @validator("CORS_ORIGINS", pre=True)
    def parse_cors_origins(cls, v):
        """Parse CORS origins from comma-separated string."""
        if isinstance(v, str):
            return [origin.strip() for origin in v.split(",")]
        return v


# Global settings instance
settings = Settings()
