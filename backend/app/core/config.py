import os
from pathlib import Path
from pydantic import BaseModel, Field

BASE_DIR = Path(__file__).resolve().parent.parent.parent

class Settings(BaseModel):
    PROJECT_NAME: str = "Ginata Property Management"
    API_V1_STR: str = "/api/v1"
    DATABASE_URL: str = os.getenv("DATABASE_URL", f"sqlite:///{BASE_DIR}/ginata.db")
    SECRET_KEY: str = os.getenv("SECRET_KEY", "ginata-secret-forest-green-key-2024")
    DEFAULT_CURRENCY: str = "KES"
    STORAGE_DIR: Path = BASE_DIR / "storage"
    DOCUMENTS_DIR: Path = BASE_DIR / "storage" / "documents"
    UPLOADS_DIR: Path = BASE_DIR / "storage" / "uploads"
    STATIC_DIR: Path = BASE_DIR / "app" / "static"
    DEFAULT_ORG_ID: str = "org-ginata-prime"
    APP_URL: str = os.getenv("APP_URL", "http://localhost:8000")
    AUTH_SESSION_TTL_HOURS: int = Field(default=int(os.getenv("AUTH_SESSION_TTL_HOURS", "168")), validate_default=True, ge=1, le=8760)
    REQUIRE_EMAIL_VERIFICATION: bool = os.getenv("REQUIRE_EMAIL_VERIFICATION", "false").lower() == "true"
    EMAIL_OTP_TTL_MINUTES: int = Field(default=int(os.getenv("EMAIL_OTP_TTL_MINUTES", "10")), validate_default=True, ge=1, le=60)
    EMAIL_OTP_MAX_ATTEMPTS: int = Field(default=int(os.getenv("EMAIL_OTP_MAX_ATTEMPTS", "5")), validate_default=True, ge=1, le=10)
    EMAIL_OTP_RESEND_SECONDS: int = Field(default=int(os.getenv("EMAIL_OTP_RESEND_SECONDS", "60")), validate_default=True, ge=1)
    SMTP_HOST: str = os.getenv("SMTP_HOST", "")
    SMTP_PORT: int = Field(default=int(os.getenv("SMTP_PORT", "587")), validate_default=True, ge=1, le=65535)
    SMTP_USERNAME: str = os.getenv("SMTP_USERNAME", "")
    SMTP_PASSWORD: str = os.getenv("SMTP_PASSWORD", "")
    SMTP_FROM_EMAIL: str = os.getenv("SMTP_FROM_EMAIL", "")
    SMTP_USE_SSL: bool = os.getenv("SMTP_USE_SSL", "false").lower() == "true"
    SMTP_STARTTLS: bool = os.getenv("SMTP_STARTTLS", "true").lower() == "true"
    SEED_DEMO_HOST: bool = os.getenv("SEED_DEMO_HOST", "false").lower() == "true"
    CORS_ALLOWED_ORIGINS: list[str] = [
        origin.strip().rstrip("/")
        for origin in os.getenv(
            "CORS_ALLOWED_ORIGINS", "http://localhost:3000,http://127.0.0.1:3000,http://localhost:8080,http://127.0.0.1:8080"
        ).split(",") if origin.strip() and origin.strip() != "*"
    ]

settings = Settings()

# Ensure directories exist
settings.DOCUMENTS_DIR.mkdir(parents=True, exist_ok=True)
settings.UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
settings.STATIC_DIR.mkdir(parents=True, exist_ok=True)
