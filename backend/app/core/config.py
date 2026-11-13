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
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "").rstrip("/")
    SUPABASE_ANON_KEY: str = os.getenv("SUPABASE_ANON_KEY", "")
    SUPABASE_SERVICE_ROLE_KEY: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    SUPABASE_STORAGE_BUCKET: str = os.getenv("SUPABASE_STORAGE_BUCKET", "ginata-media")
    ADMIN_API_KEY: str = os.getenv("ADMIN_API_KEY", "")
    SUBSCRIPTION_GRANDFATHER_BEFORE: str = os.getenv("SUBSCRIPTION_GRANDFATHER_BEFORE", "2026-11-13")
    PUBLIC_API_BASE_URL: str = os.getenv("PUBLIC_API_BASE_URL", "https://ginata-backend.onrender.com").rstrip("/")
    AUTH_REDIRECT_URLS: list[str] = [value.strip() for value in os.getenv("AUTH_REDIRECT_URLS", "com.ginata.app://login-callback,https://123159d9.ginata-application.pages.dev/app/,http://localhost:3000/app/,http://127.0.0.1:3000/app/").split(",") if value.strip()]
    RATE_LIMIT_ENABLED: bool = os.getenv("RATE_LIMIT_ENABLED", "true").lower() == "true"
    TRIAL_DAYS: int = Field(default=int(os.getenv("TRIAL_DAYS", "14")), ge=1, le=90)
    GOOGLE_CLIENT_ID: str = os.getenv("GOOGLE_CLIENT_ID", "")
    GOOGLE_CLIENT_SECRET: str = os.getenv("GOOGLE_CLIENT_SECRET", "")
    GOOGLE_REDIRECT_URI: str = os.getenv(
        "GOOGLE_REDIRECT_URI", "https://ginata-backend.onrender.com/api/v1/integrations/google/callback"
    )
    GOOGLE_TOKEN_ENCRYPTION_KEY: str = os.getenv("GOOGLE_TOKEN_ENCRYPTION_KEY", "")
    GOOGLE_OAUTH_STATE_SECRET: str = os.getenv("GOOGLE_OAUTH_STATE_SECRET", "")
    GOOGLE_OAUTH_STATE_TTL_MINUTES: int = Field(
        default=int(os.getenv("GOOGLE_OAUTH_STATE_TTL_MINUTES", "10")), validate_default=True, ge=1, le=30
    )
    GOOGLE_FORMS_POLL_SECONDS: int = Field(
        default=int(os.getenv("GOOGLE_FORMS_POLL_SECONDS", "60")), validate_default=True, ge=0, le=3600
    )
    GOOGLE_FORMS_PUBSUB_TOPIC: str = os.getenv("GOOGLE_FORMS_PUBSUB_TOPIC", "")
    GOOGLE_FORMS_PUSH_TOKEN: str = os.getenv("GOOGLE_FORMS_PUSH_TOKEN", "")
    CORS_ALLOWED_ORIGINS: list[str] = [
        origin.strip().rstrip("/")
        for origin in os.getenv(
            "CORS_ALLOWED_ORIGINS", "https://123159d9.ginata-application.pages.dev,http://localhost:3000,http://127.0.0.1:3000,http://localhost:8080,http://127.0.0.1:8080"
        ).split(",") if origin.strip() and origin.strip() != "*"
    ]
    CORS_ALLOWED_ORIGIN_REGEX: str = os.getenv(
        "CORS_ALLOWED_ORIGIN_REGEX", r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"
    )

settings = Settings()

# Ensure directories exist
settings.DOCUMENTS_DIR.mkdir(parents=True, exist_ok=True)
settings.UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
settings.STATIC_DIR.mkdir(parents=True, exist_ok=True)
