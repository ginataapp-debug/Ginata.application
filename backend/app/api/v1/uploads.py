import io
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, status
from PIL import Image, UnidentifiedImageError

from backend.app.api.deps import get_current_org_id
from backend.app.core.config import settings

router = APIRouter(prefix="/uploads", tags=["File Uploads"])

ALLOWED_FORMATS = {".jpg": "JPEG", ".jpeg": "JPEG", ".png": "PNG", ".webp": "WEBP", ".gif": "GIF"}
MAX_FILE_SIZE = 10 * 1024 * 1024


@router.post("/image", status_code=status.HTTP_201_CREATED)
async def upload_image(
    file: UploadFile = File(...),
    org_id: str = Depends(get_current_org_id),
):
    try:
        if not file.filename:
            raise HTTPException(400, "No file provided")
        ext = Path(file.filename).suffix.lower()
        if ext not in ALLOWED_FORMATS:
            raise HTTPException(400, "Choose a JPEG, PNG, WebP, or GIF cover image")
        data = await file.read(MAX_FILE_SIZE + 1)
        if len(data) > MAX_FILE_SIZE:
            raise HTTPException(400, "File exceeds maximum size of 10MB")
        try:
            with Image.open(io.BytesIO(data)) as image:
                if image.format != ALLOWED_FORMATS[ext]:
                    raise HTTPException(400, "Image content does not match its file extension")
                image.verify()
        except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError) as exc:
            raise HTTPException(400, "The selected file is not a valid image") from exc
        filename = f"{org_id}_{uuid.uuid4().hex}{ext}"
        try:
            (settings.UPLOADS_DIR / filename).write_bytes(data)
        except OSError as exc:
            raise HTTPException(500, "Unable to store the image") from exc
        return {
            "status": "success", "filename": filename,
            "original_name": file.filename, "size": len(data),
            "url": f"/uploads/{filename}",
        }
    finally:
        await file.close()
