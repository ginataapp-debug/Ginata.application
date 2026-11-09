from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select

from backend.app.core.database import get_db
from backend.app.api.deps import get_current_org_id
from backend.app.models.models import Invoice, CreditNote, GeneratedDocument
from backend.app.schemas.schemas import (
    InvoiceResponse, InvoiceUpdate, CreditNoteCreate, CreditNoteResponse,
    DocumentExportRequest, GeneratedDocumentResponse, DocumentSendRequest,
    DeliveryAttemptResponse
)
from backend.app.services.invoice_service import update_invoice, issue_invoice, create_credit_note
from backend.app.services.delivery_service import create_or_get_generated_document, send_document

router = APIRouter(prefix="/invoices", tags=["Invoices"])

@router.get("", response_model=List[InvoiceResponse])
def list_invoices(
    status_filter: Optional[str] = None,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    query = select(Invoice).where(Invoice.organization_id == org_id)
    if status_filter:
        query = query.where(Invoice.status == status_filter)
    query = query.order_by(Invoice.created_at.desc())
    return db.execute(query).scalars().all()

@router.get("/{invoice_id}", response_model=InvoiceResponse)
def get_invoice(
    invoice_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    inv = db.execute(
        select(Invoice).where(
            Invoice.id == invoice_id,
            Invoice.organization_id == org_id
        )
    ).scalar_one_or_none()
    if not inv:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invoice not found")
    return inv

@router.patch("/{invoice_id}", response_model=InvoiceResponse)
def update_invoice_endpoint(
    invoice_id: str,
    update_in: InvoiceUpdate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    return update_invoice(
        db=db,
        organization_id=org_id,
        invoice_id=invoice_id,
        update_in=update_in,
        actor_name="Host"
    )

@router.post("/{invoice_id}/issue", response_model=InvoiceResponse)
def issue_invoice_endpoint(
    invoice_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    return issue_invoice(
        db=db,
        organization_id=org_id,
        invoice_id=invoice_id,
        actor_name="Host"
    )

@router.post("/{invoice_id}/export", response_model=GeneratedDocumentResponse)
def export_invoice(
    invoice_id: str,
    export_in: DocumentExportRequest,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    gen_doc = create_or_get_generated_document(
        db=db,
        organization_id=org_id,
        invoice_id=invoice_id,
        file_format=export_in.format
    )
    return gen_doc

@router.post("/{invoice_id}/send", response_model=DeliveryAttemptResponse)
def send_invoice_endpoint(
    invoice_id: str,
    send_in: DocumentSendRequest,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    # Ensure PDF document is generated first
    gen_doc = create_or_get_generated_document(
        db=db,
        organization_id=org_id,
        invoice_id=invoice_id,
        file_format="pdf"
    )

    attempt = send_document(
        db=db,
        organization_id=org_id,
        document_id=gen_doc.id,
        channel=send_in.channel,
        recipient=send_in.recipient,
        custom_message=send_in.custom_message,
        actor_name="Host"
    )
    return attempt

@router.post("/credit-notes", response_model=CreditNoteResponse, status_code=status.HTTP_201_CREATED)
def issue_credit_note(
    credit_in: CreditNoteCreate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    return create_credit_note(
        db=db,
        organization_id=org_id,
        credit_in=credit_in,
        actor_name="Host"
    )
