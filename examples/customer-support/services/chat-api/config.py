"""Configuration management for the chat API."""
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Provider API Keys
    openai_api_key: Optional[str] = None
    anthropic_api_key: Optional[str] = None
    azure_openai_api_key: Optional[str] = None
    azure_openai_endpoint: Optional[str] = None

    # Redis Configuration
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_db: int = 0
    redis_password: Optional[str] = None

    # Provider Configuration
    default_provider: str = "anthropic"
    enable_fallback: bool = True
    rate_limit_retry_attempts: int = 3

    # Cost Optimization
    enable_prompt_caching: bool = True
    max_context_tokens: int = 100000
    auto_summarize_threshold: int = 80000
    cache_ttl_seconds: int = 3600

    # PII Detection
    enable_pii_detection: bool = True
    pii_redaction_char: str = "*"
    pii_audit_log_path: str = "./logs/pii_audit.log"

    # A/B Testing
    enable_ab_testing: bool = True
    ab_test_salt: str = "default-salt"

    # Application
    app_env: str = "development"
    log_level: str = "INFO"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="allow"
    )


settings = Settings()
