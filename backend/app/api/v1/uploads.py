from fastapi import APIRouter, Depends, UploadFile, File, status
from backend.app.api.deps import get_current_org_id
from backend.app.services.storage_service import MAX_IMAGE_BYTES, store_image, read_image
from fastapi.responses import Response

router = APIRouter(tags=["File Uploads"])


@router.post("/uploads/image", status_code=status.HTTP_201_CREATED)
def upload_image(file: UploadFile = File(...), org_id: str = Depends(get_current_org_id)):
    try:
        data = file.file.read(MAX_IMAGE_BYTES + 1)
        filename, url = store_image(data, org_id)
        return {"status": "success", "filename": filename, "original_name": file.filename, "size": len(data), "url": url}
    finally:
        file.file.close()


@router.get("/media/{key}")
def image(key: str):
    data, content_type = read_image(key)
    return Response(data, media_type=content_type, headers={"X-Content-Type-Options": "nosniff", "Cache-Control": "public, max-age=86400"})
