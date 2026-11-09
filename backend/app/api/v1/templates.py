import shutil
from pathlib import Path
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session
from sqlalchemy import select

from backend.app.core.config import settings
from backend.app.core.database import get_db
from backend.app.api.deps import get_current_org_id
from backend.app.models.models import DocumentTemplate, Organization
from backend.app.schemas.schemas import DocumentTemplateResponse, DocumentTemplateUpdate, DocumentTemplateCreate
from backend.app.services.audit_service import log_audit_event

router = APIRouter(prefix="/templates", tags=["Templates"])

@router.get("", response_model=List[DocumentTemplateResponse])
def get_templates(
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    templates = db.execute(
        select(DocumentTemplate).where(DocumentTemplate.organization_id == org_id)
    ).scalars().all()
    if not templates:
        # Create default
        default_tpl = DocumentTemplate(
            organization_id=org_id,
            name="Ginata Heritage Monograph",
            layout_style="minimalist_luxury",
            primary_color="#003329",
            secondary_color="#466557",
            font_family="Plus Jakarta Sans",
            logo_url="/static/logo.png",
            header_text="Ginata Luxury Estates & Suites",
            footer_text="Thank you for staying with Ginata. Concierge: +254 700 892 100",
            payment_instructions="M-Pesa Paybill: 247247 | Account: GINATA-STAY | Bank: KCB Bank, Forest Branch, A/C: 1122334455",
            tax_notes="VAT 16% inclusive",
            is_default=True
        )
        db.add(default_tpl)
        db.commit()
        db.refresh(default_tpl)
        templates = [default_tpl]

    return templates

@router.patch("/{template_id}", response_model=DocumentTemplateResponse)
def update_template(
    template_id: str,
    update_in: DocumentTemplateUpdate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    tpl = db.execute(
        select(DocumentTemplate).where(
            DocumentTemplate.id == template_id,
            DocumentTemplate.organization_id == org_id
        )
    ).scalar_one_or_none()
    if not tpl:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")

    if update_in.name:
        tpl.name = update_in.name
    if update_in.layout_style:
        tpl.layout_style = update_in.layout_style
    if update_in.primary_color:
        tpl.primary_color = update_in.primary_color
    if update_in.secondary_color:
        tpl.secondary_color = update_in.secondary_color
    if update_in.font_family:
        tpl.font_family = update_in.font_family
    if update_in.header_text is not None:
        tpl.header_text = update_in.header_text
    if update_in.footer_text is not None:
        tpl.footer_text = update_in.footer_text
    if update_in.payment_instructions is not None:
        tpl.payment_instructions = update_in.payment_instructions
    if update_in.tax_notes is not None:
        tpl.tax_notes = update_in.tax_notes

    log_audit_event(
        db=db,
        organization_id=org_id,
        entity_type="template",
        entity_id=tpl.id,
        action="updated_template",
        actor_name="Host",
        details={"name": tpl.name, "layout": tpl.layout_style}
    )

    db.commit()
    db.refresh(tpl)
    return tpl

@router.post("/{template_id}/logo", response_model=DocumentTemplateResponse)
async def upload_template_logo(
    template_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    tpl = db.execute(
        select(DocumentTemplate).where(
            DocumentTemplate.id == template_id,
            DocumentTemplate.organization_id == org_id
        )
    ).scalar_one_or_none()
    if not tpl:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")

    # Validate file type
    content_type = file.content_type or ""
    if not (content_type.startswith("image/png") or content_type.startswith("image/jpeg") or content_type.startswith("image/webp")):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid image format. Allowed formats: PNG, JPEG, WEBP."
        )

    # Secure filename isolated to tenant
    ext = Path(file.filename or "logo.png").suffix.lower()
    if not ext:
        ext = ".png"
    safe_name = f"logo_{org_id}_{tpl.id[:8]}{ext}"
    dest_path = settings.UPLOADS_DIR / safe_name

    with open(dest_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # Update template and organization logo URL
    logo_relative_url = f"/uploads/{safe_name}"
    tpl.logo_url = str(dest_path)

    org = db.execute(select(Organization).where(Organization.id == org_id)).scalar_one_or_none()
    if org:
        org.logo_url = str(dest_path)

    log_audit_event(
        db=db,
        organization_id=org_id,
        entity_type="template",
        entity_id=tpl.id,
        action="uploaded_logo",
        actor_name="Host",
        details={"logo_name": safe_name}
    )

    db.commit()
    db.refresh(tpl)
    return tpl
