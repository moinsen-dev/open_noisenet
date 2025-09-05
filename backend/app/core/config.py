"""
Application configuration settings.
"""

import secrets
from typing import Any, Dict, List, Optional, Union

from pydantic import AnyHttpUrl, EmailStr, Field, field_validator
from pydantic_settings import BaseSettings
try:
    from pydantic.v1 import PostgresDsn
except ImportError:
    from pydantic import PostgresDsn


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # Project information
    PROJECT_NAME: str = "OpenNoiseNet API"
    API_V1_STR: str = "/api/v1"
    
    # Environment
    ENVIRONMENT: str = Field(default="development", env="ENVIRONMENT")
    DEBUG: bool = Field(default=False)
    
    # Security
    SECRET_KEY: str = Field(..., min_length=32)
    JWT_SECRET_KEY: str = Field(default="", description="JWT signing key")
    JWT_ALGORITHM: str = Field(default="HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(default=30)
    REFRESH_TOKEN_EXPIRE_DAYS: int = Field(default=30)
    
    # Database - simplified for now
    DATABASE_URL: str = Field(default="postgresql+asyncpg://noisenet:changeme@localhost:5432/noisenet")

    # Redis
    REDIS_URL: str = Field(default="redis://localhost:6379")
    
    # CORS - simplified
    BACKEND_CORS_ORIGINS: List[str] = Field(
        default=["http://localhost:3000", "http://localhost:8080"],
        description="CORS allowed origins"
    )
    
    # Trusted hosts
    ALLOWED_HOSTS: List[str] = Field(
        default=["localhost", "127.0.0.1", "0.0.0.0", "backend", "*"],
        description="Allowed host headers"
    )

    # Audio processing settings
    MAX_AUDIO_SNIPPET_SIZE_MB: int = Field(default=10)
    AUDIO_RETENTION_DAYS: int = Field(default=7)
    ENABLE_AUDIO_SNIPPETS: bool = Field(default=False)
    SUPPORTED_AUDIO_CODECS: List[str] = Field(
        default=["opus", "wav", "flac", "mp3"]
    )

    # Rate limiting
    API_RATE_LIMIT_PER_MINUTE: int = Field(default=60)
    DEVICE_EVENT_RATE_LIMIT_PER_HOUR: int = Field(default=1000)

    # Geospatial settings
    DEFAULT_MAP_CENTER_LAT: float = Field(default=52.520008)
    DEFAULT_MAP_CENTER_LNG: float = Field(default=13.404954)
    DEFAULT_MAP_ZOOM: int = Field(default=10)

    # Email settings (optional)
    SMTP_TLS: bool = Field(default=True)
    SMTP_PORT: Optional[int] = Field(default=None)
    SMTP_HOST: Optional[str] = Field(default=None)
    SMTP_USER: Optional[str] = Field(default=None)
    SMTP_PASSWORD: Optional[str] = Field(default=None)
    EMAILS_FROM_EMAIL: Optional[str] = Field(default=None)
    EMAILS_FROM_NAME: Optional[str] = Field(default="OpenNoiseNet")

    # Superuser
    FIRST_SUPERUSER_EMAIL: Optional[str] = Field(default=None)
    FIRST_SUPERUSER_PASSWORD: Optional[str] = Field(default=None)

    # Logging
    LOG_LEVEL: str = Field(default="INFO")
    LOG_FORMAT: str = Field(default="json")

    # Cloud storage (optional)
    USE_S3: bool = Field(default=False)
    AWS_ACCESS_KEY_ID: Optional[str] = Field(default=None)
    AWS_SECRET_ACCESS_KEY: Optional[str] = Field(default=None)
    AWS_S3_BUCKET: Optional[str] = Field(default=None)
    AWS_REGION: str = Field(default="eu-central-1")

    # Monitoring and observability
    SENTRY_DSN: Optional[str] = Field(default=None)
    ENABLE_METRICS: bool = Field(default=True)

    # Noise analysis settings
    DEFAULT_NOISE_THRESHOLDS: Dict[str, float] = Field(
        default={
            "day_leq": 65.0,
            "night_leq": 55.0,
            "peak_threshold": 85.0,
        }
    )

    # AI model settings
    AI_MODEL_CONFIG: Dict[str, Any] = Field(
        default={
            "primary": "minicpm-o-2.6",
            "fallback": "yamnet",
            "confidence_threshold": 0.7,
        }
    )

    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"


settings = Settings()