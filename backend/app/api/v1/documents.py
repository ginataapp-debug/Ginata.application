from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from sqlalchemy import select

from backend.app.core.database import get_db
from backend.app.api.deps import get_current_org_id
from backend.app.models.models import GeneratedDocument
from backend.app.schemas.schemas import GeneratedDocumentResponse
from backend.app.services.delivery_service import get_secure_download_file

router = APIRouter(tags=["Documents"])

@router.get("/documents", response_model=List[GeneratedDocumentResponse])
def list_documents(
    reservation_id: Optional[str] = None,
    document_type: Optional[str] = None,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    query = select(GeneratedDocument).where(GeneratedDocument.organization_id == org_id)
    if reservation_id:
        query = query.where(GeneratedDocument.reservation_id == reservation_id)
    if document_type:
        query = query.where(GeneratedDocument.document_type == document_type)
    query = query.order_by(GeneratedDocument.created_at.desc())
    return db.execute(query).scalars().all()

@router.get("/documents/{document_id}/download")
def authorized_download(
    document_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    doc = db.execute(
        select(GeneratedDocument).where(
            GeneratedDocument.id == document_id,
            GeneratedDocument.organization_id == org_id
        )
    ).scalar_one_or_none()
    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")

    file_path, file_name, media_type = get_secure_download_file(db, doc.secure_token)
    return FileResponse(
        path=file_path,
        filename=file_name,
        media_type=media_type
    )

@router.get("/public/documents/{token}/download")
def public_secure_download(
    token: str,
    db: Session = Depends(get_db)
):
    file_path, file_name, media_type = get_secure_download_file(db, token)
    return FileResponse(
        path=file_path,
        filename=file_name,
        media_type=media_type
    )
