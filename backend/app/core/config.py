import os
from pathlib import Path
from pydantic import BaseModel

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

settings = Settings()

# Ensure directories exist
settings.DOCUMENTS_DIR.mkdir(parents=True, exist_ok=True)
settings.UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
settings.STATIC_DIR.mkdir(parents=True, exist_ok=True)
