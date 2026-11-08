from datetime import timezone, datetime, date
from decimal import Decimal
from typing import Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select

from backend.app.models.models import (
    Payment, PaymentAllocation, Receipt, Reservation, Invoice, Organization
)
from backend.app.schemas.schemas import PaymentCreate
from backend.app.services.audit_service import log_audit_event
from backend.app.services.sequence_service import get_next_sequence_number

def record_payment_and_issue_receipt(
    db: Session,
    organization_id: str,
    payment_in: PaymentCreate,
    actor_name: str = "Host Clara"
) -> Payment:
    """
    Records a payment against a reservation (and optional invoice),
    allocates the amount, updates balances, and issues a single receipt.
    Guarantees no duplicate receipt for the same payment event.
    Distinguishes manually recorded payments from verified provider payments.
    """
    res = db.execute(
        select(Reservation).where(
            Reservation.id == payment_in.reservation_id,
            Reservation.organization_id == organization_id
        )
    ).scalar_one_or_none()
    if not res:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reservation not found")

    pay_amount = Decimal(str(payment_in.amount))
    if pay_amount <= Decimal("0.00"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Payment amount must be greater than zero")

    invoice = None
    if payment_in.invoice_id:
        invoice = db.execute(
            select(Invoice).where(
                Invoice.id == payment_in.invoice_id,
                Invoice.organization_id == organization_id
            )
        ).scalar_one_or_none()

    # 1. Create Payment
    payment = Payment(
        organization_id=organization_id,
        reservation_id=res.id,
        invoice_id=invoice.id if invoice else None,
        amount=pay_amount,
        currency=payment_in.currency or res.currency or "KES",
        payment_method=payment_in.payment_method,
        transaction_reference=payment_in.transaction_reference,
        is_verified=payment_in.is_verified,
        verification_source=payment_in.verification_source,
        payment_date=payment_in.payment_date or datetime.now(timezone.utc).replace(tzinfo=None),
        notes=payment_in.notes
    )
    db.add(payment)
    db.flush()

    # 2. Allocate payment to invoice if linked
    if invoice:
        alloc = PaymentAllocation(
            payment_id=payment.id,
            invoice_id=invoice.id,
            allocated_amount=pay_amount
        )
        db.add(alloc)
        invoice.amount_paid += pay_amount
        invoice.balance_due = max(Decimal("0.00"), invoice.grand_total - invoice.amount_paid)
        if invoice.balance_due == 0:
            invoice.status = "paid"
        else:
            invoice.status = "partially_paid"

    # 3. Update reservation balances
    res.amount_paid += pay_amount
    res.balance_due = max(Decimal("0.00"), res.total_amount - res.amount_paid)
    if res.balance_due == 0:
        res.payment_status = "paid"
    else:
        res.payment_status = "partial"

    # 4. Issue unique receipt
    receipt_no = get_next_sequence_number(db, organization_id, "REC")
    guest_name = f"{res.primary_guest.first_name} {res.primary_guest.last_name}" if res.primary_guest else "Valued Guest"
    remaining_bal = invoice.balance_due if invoice else res.balance_due

    receipt = Receipt(
        organization_id=organization_id,
        payment_id=payment.id,
        receipt_number=receipt_no,
        receipt_date=date.today(),
        amount_received=pay_amount,
        currency=payment.currency,
        payment_method=payment.payment_method,
        transaction_reference=payment.transaction_reference,
        remaining_balance=remaining_bal,
        issued_to_name=guest_name,
        issued_by_name=actor_name
    )
    db.add(receipt)

    # 5. Audit Log
    log_audit_event(
        db=db,
        organization_id=organization_id,
        entity_type="payment",
        entity_id=payment.id,
        action="payment_recorded",
        actor_name=actor_name,
        details={
            "amount": str(pay_amount),
            "currency": payment.currency,
            "method": payment.payment_method,
            "receipt_number": receipt_no,
            "is_verified": payment.is_verified,
            "verification_source": payment.verification_source,
            "remaining_balance": str(remaining_bal)
        }
    )

    db.commit()
    db.refresh(payment)
    return payment


def update_receipt(
    db: Session,
    organization_id: str,
    receipt_id: str,
    update_in,
    actor_name: str = "Host Clara"
) -> Receipt:
    """Updates permitted receipt details with audit logging."""
    receipt = db.execute(
        select(Receipt).where(
            Receipt.id == receipt_id,
            Receipt.organization_id == organization_id
        )
    ).scalar_one_or_none()
    if not receipt:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Receipt not found")

    if update_in.receipt_date is not None:
        receipt.receipt_date = update_in.receipt_date
    if update_in.payment_method is not None:
        receipt.payment_method = update_in.payment_method
        if receipt.payment:
            receipt.payment.payment_method = update_in.payment_method
    if update_in.transaction_reference is not None:
        receipt.transaction_reference = update_in.transaction_reference
        if receipt.payment:
            receipt.payment.transaction_reference = update_in.transaction_reference
    if update_in.issued_to_name is not None:
        receipt.issued_to_name = update_in.issued_to_name
    if update_in.issued_by_name is not None:
        receipt.issued_by_name = update_in.issued_by_name
    if update_in.remaining_balance is not None:
        receipt.remaining_balance = update_in.remaining_balance

    if update_in.amount_received is not None:
        new_amount = Decimal(str(update_in.amount_received))
        old_amount = receipt.amount_received
        diff = new_amount - old_amount
        receipt.amount_received = new_amount
        if receipt.payment:
            receipt.payment.amount = new_amount
            res = receipt.payment.reservation
            if res:
                res.amount_paid += diff
                res.balance_due = max(Decimal("0.00"), res.total_amount - res.amount_paid)
                res.payment_status = "paid" if res.balance_due == 0 else "partial"
                receipt.remaining_balance = res.balance_due

    log_audit_event(
        db=db,
        organization_id=organization_id,
        entity_type="receipt",
        entity_id=receipt.id,
        action="updated_receipt",
        actor_name=actor_name,
        details={
            "receipt_number": receipt.receipt_number,
            "amount_received": str(receipt.amount_received)
        }
    )

    db.commit()
    db.refresh(receipt)
    return receipt

