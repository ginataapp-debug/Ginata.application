import shutil
from datetime import date
from decimal import Decimal
from pathlib import Path
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session
from sqlalchemy import select

from backend.app.core.config import settings
from backend.app.core.database import get_db
from backend.app.api.deps import get_current_org_id
from backend.app.models.models import DocumentTemplate, Organization, Invoice, InvoiceLineItem
from fastapi.responses import Response
from backend.app.services.document_generator import generate_invoice_pdf
from backend.app.schemas.schemas import DocumentTemplateResponse, DocumentTemplateUpdate, DocumentTemplateCreate
from backend.app.services.audit_service import log_audit_event
from backend.app.services.delivery_service import regenerate_documents_with_template

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
            name="Standard Minimalist Luxury",
            layout_style="minimalist_luxury",
            primary_color="#003329",
            secondary_color="#466557",
            font_family="Plus Jakarta Sans",
            logo_url="/static/logo.png",
            header_text="Ginata Luxury Estates & Suites",
            footer_text="Thank you for staying with us.",
            payment_instructions="Contact host for payment details",
            tax_notes="Tax amounts are itemized where applicable.",
            is_default=True
        )
        db.add(default_tpl)
        db.commit()
        db.refresh(default_tpl)
        templates = [default_tpl]

    return templates


@router.post("", response_model=DocumentTemplateResponse, status_code=status.HTTP_201_CREATED)
def create_template(
    create_in: DocumentTemplateCreate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    from backend.app.models.models import Property
    if create_in.property_id and not db.scalar(select(Property.id).where(Property.id == create_in.property_id, Property.organization_id == org_id)):
        raise HTTPException(404, "Property not found")
    if create_in.is_default:
        existing = db.execute(
            select(DocumentTemplate).where(
                DocumentTemplate.organization_id == org_id,
                DocumentTemplate.is_default == True
            )
        ).scalars().all()
        for t in existing:
            t.is_default = False

    tpl = DocumentTemplate(
        organization_id=org_id,
        property_id=create_in.property_id,
        name=create_in.name,
        layout_style=create_in.layout_style,
        primary_color=create_in.primary_color,
        secondary_color=create_in.secondary_color,
        font_family=create_in.font_family,
        logo_url=create_in.logo_url,
        header_text=create_in.header_text,
        footer_text=create_in.footer_text,
        payment_instructions=create_in.payment_instructions,
        tax_notes=create_in.tax_notes,
        is_default=create_in.is_default,
    )
    db.add(tpl)
    db.commit()
    db.refresh(tpl)
    return tpl


@router.post("/preview")
def preview_document_template(
    design: DocumentTemplateUpdate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id),
):
    org = db.get(Organization, org_id)
    template = DocumentTemplate(**design.model_dump(exclude_unset=True))
    invoice = Invoice(
        supplier_name=design.header_text or org.name,
        supplier_address=org.address,
        supplier_email=org.email,
        supplier_phone=org.phone,
        supplier_logo_url=org.logo_url,
        billing_name="Sample Guest",
        invoice_number="PREVIEW-001",
        document_type="invoice",
        status="draft",
        issue_date=date.today(),
        due_date=date.today(),
        currency="KES",
        subtotal=Decimal("104000"),
        tax_total=Decimal("0"),
        discount_total=Decimal("1000"),
        grand_total=Decimal("103000"),
        amount_paid=Decimal("0"),
        balance_due=Decimal("103000"),
        payment_instructions=design.payment_instructions,
        footer=design.footer_text,
        line_items=[
            InvoiceLineItem(description="Accommodation: 4 nights", quantity=Decimal("4"), unit_price=Decimal("25000"), tax_amount=Decimal("0"), total_amount=Decimal("100000")),
            InvoiceLineItem(description="Cleaning and turnover", quantity=Decimal("1"), unit_price=Decimal("4000"), tax_amount=Decimal("0"), total_amount=Decimal("4000")),
            InvoiceLineItem(description="Stay discount", quantity=Decimal("1"), unit_price=Decimal("0"), tax_amount=Decimal("0"), total_amount=Decimal("-1000")),
        ],
    )
    return Response(generate_invoice_pdf(invoice, template=template), media_type="application/pdf")


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
    if update_in.is_default is not None:
        if update_in.is_default:
            others = db.execute(
                select(DocumentTemplate).where(
                    DocumentTemplate.organization_id == org_id,
                    DocumentTemplate.id != tpl.id,
                    DocumentTemplate.is_default == True
                )
            ).scalars().all()
            for t in others:
                t.is_default = False
        tpl.is_default = update_in.is_default

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

    from backend.app.services.storage_service import MAX_IMAGE_BYTES, store_image
    try:
        data = await file.read(MAX_IMAGE_BYTES + 1)
        safe_name, logo_url = store_image(data, org_id)
    finally:
        await file.close()
    tpl.logo_url = logo_url

    org = db.execute(select(Organization).where(Organization.id == org_id)).scalar_one_or_none()
    if org:
        org.logo_url = logo_url

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


@router.post("/{template_id}/apply")
def apply_template_to_documents(
    template_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    """
    Makes this template the organization default and re-renders every archived
    invoice/receipt PDF with its layout, typography and colors.
    """
    tpl = db.execute(
        select(DocumentTemplate).where(
            DocumentTemplate.id == template_id,
            DocumentTemplate.organization_id == org_id
        )
    ).scalar_one_or_none()
    if not tpl:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")

    # Promote to default so newly generated documents use it too.
    if not tpl.is_default:
        others = db.execute(
            select(DocumentTemplate).where(
                DocumentTemplate.organization_id == org_id,
                DocumentTemplate.id != tpl.id,
                DocumentTemplate.is_default == True
            )
        ).scalars().all()
        for t in others:
            t.is_default = False
        tpl.is_default = True

    regenerated = regenerate_documents_with_template(db, org_id, tpl)

    log_audit_event(
        db=db,
        organization_id=org_id,
        entity_type="template",
        entity_id=tpl.id,
        action="applied_template_to_documents",
        actor_name="Host",
        details={
            "layout_style": tpl.layout_style,
            "font_family": tpl.font_family,
            "documents_regenerated": regenerated,
        }
    )

    db.commit()
    db.refresh(tpl)
    return {
        "status": "applied",
        "template_id": tpl.id,
        "layout_style": tpl.layout_style,
        "font_family": tpl.font_family,
        "primary_color": tpl.primary_color,
        "secondary_color": tpl.secondary_color,
        "documents_regenerated": regenerated,
    }
