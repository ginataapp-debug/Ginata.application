import io
import re
import uuid

import httpx
from fastapi import HTTPException
from PIL import Image, UnidentifiedImageError
from backend.app.core.config import settings

MAX_IMAGE_BYTES = 5 * 1024 * 1024
FORMATS = {"JPEG": ("jpg", "image/jpeg"), "PNG": ("png", "image/png"), "WEBP": ("webp", "image/webp"), "GIF": ("gif", "image/gif")}
KEY_PATTERN = re.compile(r"^[a-f0-9]{32}\.(jpg|png|webp|gif)$")


def validate_image(data):
    if not data or len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(400, "Choose an image up to 5MB")
    try:
        with Image.open(io.BytesIO(data)) as image:
            if image.format not in FORMATS or image.width * image.height > 25_000_000:
                raise HTTPException(400, "Choose a JPEG, PNG, WebP or GIF image up to 25 megapixels")
            image.verify()
            return FORMATS[image.format]
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError) as exc:
        raise HTTPException(400, "Invalid image file") from exc


def storage_headers():
    return {"Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}", "apikey": settings.SUPABASE_SERVICE_ROLE_KEY}


def store_image(data, org_id=None):
    ext, content_type = validate_image(data)
    key = f"{uuid.uuid4().hex}.{ext}"
    if settings.SUPABASE_URL and settings.SUPABASE_SERVICE_ROLE_KEY:
        try:
            response = httpx.post(f"{settings.SUPABASE_URL}/storage/v1/object/{settings.SUPABASE_STORAGE_BUCKET}/{key}", headers={**storage_headers(), "Content-Type": content_type}, content=data, timeout=30)
            response.raise_for_status()
        except httpx.HTTPError as exc:
            raise HTTPException(503, "Image storage is unavailable. Please try again.") from exc
        return key, f"{settings.PUBLIC_API_BASE_URL}/api/v1/media/{key}"
    if org_id:
        key = f"{org_id}_{key}"
    try:
        (settings.UPLOADS_DIR / key).write_bytes(data)
    except OSError as exc:
        raise HTTPException(503, "Image storage is unavailable") from exc
    return key, f"/uploads/{key}"


def read_image(key):
    if not KEY_PATTERN.fullmatch(key):
        raise HTTPException(404, "Image not found")
    if not settings.SUPABASE_URL or not settings.SUPABASE_SERVICE_ROLE_KEY:
        path = settings.UPLOADS_DIR / key
        if not path.is_file():
            raise HTTPException(404, "Image not found")
        data = path.read_bytes()
    else:
        try:
            with httpx.stream("GET", f"{settings.SUPABASE_URL}/storage/v1/object/authenticated/{settings.SUPABASE_STORAGE_BUCKET}/{key}", headers=storage_headers(), timeout=30) as response:
                if response.status_code == 404:
                    raise HTTPException(404, "Image not found")
                response.raise_for_status()
                buffer = bytearray()
                for chunk in response.iter_bytes():
                    buffer.extend(chunk)
                    if len(buffer) > MAX_IMAGE_BYTES:
                        raise HTTPException(400, "Invalid image")
                data = bytes(buffer)
        except httpx.HTTPError as exc:
            raise HTTPException(503, "Image storage is unavailable") from exc
    _, content_type = validate_image(data)
    return data, content_type
