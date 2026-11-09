from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select

from backend.app.core.database import get_db
from backend.app.api.deps import get_current_org_id
from backend.app.models.models import (
    Reservation, Property, PropertyUnit, Guest, GuestFormSubmission,
    Invoice, Payment, Receipt, CreditNote, AuditLog
)
from backend.app.schemas.schemas import (
    ReservationResponse, ReservationCreate, ReservationUpdate,
    ConflictCheckRequest, ConflictCheckResponse, GuestFormSubmissionResponse,
    InvoiceCreate, InvoiceResponse, ReservationFinancialTimeline, FinancialTimelineItem
)
from backend.app.services.reservation_service import (
    create_manual_booking, update_reservation, cancel_reservation, check_booking_conflicts
)
from backend.app.services.guest_form_service import get_or_generate_reservation_form_token
from backend.app.services.invoice_service import create_invoice_from_reservation
from backend.app.services.audit_service import log_audit_event

router = APIRouter(prefix="/reservations", tags=["Reservations"])

@router.get("", response_model=List[ReservationResponse])
def list_reservations(
    property_id: Optional[str] = None,
    status_filter: Optional[str] = None,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    query = select(Reservation).where(Reservation.organization_id == org_id)
    if property_id:
        query = query.where(Reservation.property_id == property_id)
    if status_filter:
        query = query.where(Reservation.reservation_status == status_filter)

    query = query.order_by(Reservation.check_in_date.desc())
    reservations = db.execute(query).scalars().all()
    return reservations

@router.post("", response_model=ReservationResponse, status_code=status.HTTP_201_CREATED)
def create_reservation(
    booking_in: ReservationCreate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    return create_manual_booking(
        db=db,
        organization_id=org_id,
        booking_in=booking_in,
        actor_name="Host"
    )

@router.post("/check-conflicts", response_model=ConflictCheckResponse)
def check_conflicts_endpoint(
    req: ConflictCheckRequest,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    conflicts = check_booking_conflicts(
        db=db,
        organization_id=org_id,
        property_id=req.property_id,
        check_in_date=req.check_in_date,
        check_out_date=req.check_out_date,
        unit_id=req.unit_id,
        exclude_reservation_id=req.exclude_reservation_id
    )
    has_conflict = len(conflicts) > 0
    msg = f"{len(conflicts)} overlapping reservation(s) detected" if has_conflict else "Dates are clear and available"
    return ConflictCheckResponse(
        has_conflict=has_conflict,
        message=msg,
        conflicts=conflicts
    )

@router.get("/{reservation_id}", response_model=ReservationResponse)
def get_reservation(
    reservation_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    res = db.execute(
        select(Reservation).where(
            Reservation.id == reservation_id,
            Reservation.organization_id == org_id
        )
    ).scalar_one_or_none()
    if not res:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reservation not found")
    return res

@router.patch("/{reservation_id}", response_model=ReservationResponse)
def update_reservation_endpoint(
    reservation_id: str,
    update_in: ReservationUpdate,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    return update_reservation(
        db=db,
        organization_id=org_id,
        reservation_id=reservation_id,
        update_in=update_in,
        actor_name="Host"
    )

@router.post("/{reservation_id}/confirm", response_model=ReservationResponse)
def confirm_reservation(
    reservation_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    res = db.execute(
        select(Reservation).where(
            Reservation.id == reservation_id,
            Reservation.organization_id == org_id
        )
    ).scalar_one_or_none()
    if not res:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reservation not found")

    res.reservation_status = "confirmed"
    # Ensure guest form token is generated
    get_or_generate_reservation_form_token(db, org_id, res.id)

    log_audit_event(
        db=db,
        organization_id=org_id,
        entity_type="reservation",
        entity_id=res.id,
        action="confirmed_reservation",
        actor_name="Host",
        details={"status": "confirmed"}
    )
    db.commit()
    db.refresh(res)
    return res

@router.post("/{reservation_id}/cancel", response_model=ReservationResponse)
def cancel_reservation_endpoint(
    reservation_id: str,
    reason: Optional[str] = None,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    return cancel_reservation(
        db=db,
        organization_id=org_id,
        reservation_id=reservation_id,
        reason=reason,
        actor_name="Host"
    )

@router.post("/{reservation_id}/guest-form", response_model=GuestFormSubmissionResponse)
def generate_guest_form(
    reservation_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    submission = get_or_generate_reservation_form_token(db, org_id, reservation_id)
    return submission

@router.post("/{reservation_id}/invoices", response_model=InvoiceResponse, status_code=status.HTTP_201_CREATED)
def create_reservation_invoice(
    reservation_id: str,
    invoice_payload: Optional[InvoiceCreate] = None,
    doc_type: str = "invoice",
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    if invoice_payload:
        invoice_payload.reservation_id = reservation_id
        return create_invoice_from_reservation(db, org_id, invoice_payload)
    inv_in = InvoiceCreate(
        reservation_id=reservation_id,
        document_type=doc_type
    )
    return create_invoice_from_reservation(db, org_id, inv_in)

@router.get("/{reservation_id}/financial-timeline", response_model=ReservationFinancialTimeline)
def get_reservation_financial_timeline(
    reservation_id: str,
    db: Session = Depends(get_db),
    org_id: str = Depends(get_current_org_id)
):
    """
    Maintains a unified financial timeline for the reservation:
    e.g. Booking confirmed -> Deposit paid -> Receipt issued -> Invoice issued -> Final balance paid.
    """
    res = db.execute(
        select(Reservation).where(
            Reservation.id == reservation_id,
            Reservation.organization_id == org_id
        )
    ).scalar_one_or_none()
    if not res:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reservation not found")

    timeline: List[FinancialTimelineItem] = []

    # 1. Booking creation
    timeline.append(FinancialTimelineItem(
        type="reservation_confirmed",
        date=res.created_at,
        title="Stay Confirmed",
        description=f"Stay booked for {res.number_of_nights} nights ({res.check_in_date} to {res.check_out_date}) via {res.booking_source.upper()}",
        amount=res.total_amount,
        currency=res.currency,
        reference_id=res.booking_reference or res.id[:8]
    ))

    # 2. Invoices
    for inv in res.invoices:
        timeline.append(FinancialTimelineItem(
            type="invoice_issued" if inv.status == "issued" else "invoice_drafted",
            date=inv.issued_at or inv.created_at,
            title=f"{inv.document_type.replace('_', ' ').title()} #{inv.invoice_number}",
            description=f"Grand total {inv.currency} {inv.grand_total:,.2f} billed to {inv.billing_name} ({inv.status.upper()})",
            amount=inv.grand_total,
            currency=inv.currency,
            reference_id=inv.invoice_number
        ))
        for cn in inv.credit_notes:
            timeline.append(FinancialTimelineItem(
                type="credit_note",
                date=cn.issued_at,
                title=f"Credit Note #{cn.credit_note_number}",
                description=f"Credit of {cn.currency} {cn.amount:,.2f}: {cn.reason}",
                amount=-cn.amount,
                currency=cn.currency,
                reference_id=cn.credit_note_number
            ))

    # 3. Payments and Receipts
    for pay in res.payments:
        timeline.append(FinancialTimelineItem(
            type="payment_recorded",
            date=pay.payment_date,
            title=f"Payment Received ({pay.payment_method.upper()})",
            description=f"Transaction Ref: {pay.transaction_reference or 'Direct'}. Verified: {pay.is_verified}",
            amount=pay.amount,
            currency=pay.currency,
            reference_id=pay.transaction_reference or pay.id[:8]
        ))
        if pay.receipt:
            timeline.append(FinancialTimelineItem(
                type="receipt_issued",
                date=pay.receipt.created_at,
                title=f"Official Receipt #{pay.receipt.receipt_number}",
                description=f"Issued to {pay.receipt.issued_to_name}. Remaining balance: {pay.receipt.currency} {pay.receipt.remaining_balance:,.2f}",
                amount=pay.receipt.amount_received,
                currency=pay.receipt.currency,
                reference_id=pay.receipt.receipt_number
            ))

    timeline.sort(key=lambda x: x.date)

    return ReservationFinancialTimeline(
        reservation_id=res.id,
        total_amount=res.total_amount,
        amount_paid=res.amount_paid,
        balance_due=res.balance_due,
        currency=res.currency,
        timeline=timeline
    )
