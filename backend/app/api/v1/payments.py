from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select

from backend.app.core.database import get_db
from backend.app.api.deps import get_current_org_id
from backend.app.models.models import Payment, Receipt, GeneratedDocument
from backend.app.schemas.schemas import (
    PaymentResponse, PaymentCreate, ReceiptResponse, ReceiptUpdate, GeneratedDocumentResponse, DocumentExportRequest
)
from backend.app.services.payment_service import record_payment_and_issue_receipt, update_receipt
from backend.app.services.delivery_service import create_or_get_generated_document

router = APIRouter(prefix="/payments", tags=["Payments"])

@router.get("", response_model=List[PaymentResponse])
def list_payments(
    reservation_id: Optional[str] = None,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    query = select(Payment).where(Payment.organization_id == org_id)
    if reservation_id:
        query = query.where(Payment.reservation_id == reservation_id)
    query = query.order_by(Payment.payment_date.desc())
    return db.execute(query).scalars().all()

@router.post("", response_model=PaymentResponse, status_code=status.HTTP_201_CREATED)
def record_payment(
    payment_in: PaymentCreate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    return record_payment_and_issue_receipt(
        db=db,
        organization_id=org_id,
        payment_in=payment_in,
        actor_name="Host Clara"
    )

@router.get("/receipts", response_model=List[ReceiptResponse])
def list_receipts(
    reservation_id: Optional[str] = None,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    query = select(Receipt).where(Receipt.organization_id == org_id)
    if reservation_id:
        query = query.join(Payment).where(Payment.reservation_id == reservation_id)
    query = query.order_by(Receipt.receipt_date.desc(), Receipt.created_at.desc())
    return db.execute(query).scalars().all()

@router.get("/receipts/{receipt_id}", response_model=ReceiptResponse)
def get_receipt(
    receipt_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    rec = db.execute(
        select(Receipt).where(
            Receipt.id == receipt_id,
            Receipt.organization_id == org_id
        )
    ).scalar_one_or_none()
    if not rec:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Receipt not found")
    return rec

@router.patch("/receipts/{receipt_id}", response_model=ReceiptResponse)
def update_receipt_endpoint(
    receipt_id: str,
    update_in: ReceiptUpdate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    return update_receipt(
        db=db,
        organization_id=org_id,
        receipt_id=receipt_id,
        update_in=update_in,
        actor_name="Host Clara"
    )

@router.post("/receipts/{receipt_id}/export", response_model=GeneratedDocumentResponse)
def export_receipt(
    receipt_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    gen_doc = create_or_get_generated_document(
        db=db,
        organization_id=org_id,
        receipt_id=receipt_id,
        file_format="pdf"
    )
    return gen_doc
