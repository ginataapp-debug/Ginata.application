import secrets
from datetime import timezone, datetime, date, timedelta
from decimal import Decimal
from typing import List, Optional, Tuple, Dict, Any
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select, and_, or_

from backend.app.models.models import (
    Reservation, Property, PropertyUnit, Guest, GuestFormSubmission,
    Payment, Receipt, AuditLog
)
from backend.app.schemas.schemas import (
    ReservationCreate, ReservationUpdate, ConflictCheckResponse, ConflictDetail
)
from backend.app.services.audit_service import log_audit_event
from backend.app.services.sequence_service import get_next_sequence_number

def check_booking_conflicts(
    db: Session,
    organization_id: str,
    property_id: str,
    check_in_date: date,
    check_out_date: date,
    unit_id: Optional[str] = None,
    exclude_reservation_id: Optional[str] = None
) -> List[ConflictDetail]:
    """
    Checks for overlapping reservations.
    Checkout boundary is respected:
    Check-out at 11:00 AM on Day X does NOT conflict with Check-in at 3:00 PM on Day X.
    Overlap condition: (new_check_in < existing_check_out) AND (new_check_out > existing_check_in)
    """
    if check_out_date <= check_in_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Check-out date must be after check-in date"
        )

    query = select(Reservation).where(
        Reservation.organization_id == organization_id,
        Reservation.property_id == property_id,
        Reservation.reservation_status != "cancelled",
        and_(
            Reservation.check_in_date < check_out_date,
            Reservation.check_out_date > check_in_date
        )
    )

    if unit_id:
        query = query.where(
            or_(
                Reservation.unit_id == unit_id,
                Reservation.unit_id.is_(None)
            )
        )

    if exclude_reservation_id:
        query = query.where(Reservation.id != exclude_reservation_id)

    conflicting_reservations = db.execute(query).scalars().all()

    conflicts: List[ConflictDetail] = []
    for res in conflicting_reservations:
        guest_name = f"{res.primary_guest.first_name} {res.primary_guest.last_name}" if res.primary_guest else "Unknown"
        conflicts.append(ConflictDetail(
            reservation_id=res.id,
            booking_reference=res.booking_reference,
            guest_name=guest_name,
            check_in_date=res.check_in_date,
            check_out_date=res.check_out_date,
            reservation_status=res.reservation_status
        ))

    from backend.app.models.models import ExternalCalendarBlock
    blocks = db.scalars(select(ExternalCalendarBlock).where(ExternalCalendarBlock.organization_id == organization_id, ExternalCalendarBlock.property_id == property_id, ExternalCalendarBlock.start_date < check_out_date, ExternalCalendarBlock.end_date > check_in_date))
    for block in blocks:
        conflicts.append(ConflictDetail(reservation_id=block.id, booking_reference=block.source, guest_name="External calendar block", check_in_date=block.start_date, check_out_date=block.end_date, reservation_status="external"))
    return conflicts


def get_or_create_guest(
    db: Session,
    organization_id: str,
    first_name: str,
    last_name: str,
    email: Optional[str] = None,
    phone: Optional[str] = None
) -> Guest:
    """Finds existing guest by email or phone within organization, or creates new guest."""
    guest = None
    if email:
        guest = db.execute(
            select(Guest).where(
                Guest.organization_id == organization_id,
                Guest.email == email
            )
        ).scalar_one_or_none()

    if not guest and phone:
        guest = db.execute(
            select(Guest).where(
                Guest.organization_id == organization_id,
                Guest.phone == phone
            )
        ).scalar_one_or_none()

    if not guest:
        guest = Guest(
            organization_id=organization_id,
            first_name=first_name.strip(),
            last_name=last_name.strip(),
            email=email.strip().lower() if email else None,
            phone=phone.strip() if phone else None
        )
        db.add(guest)
        db.flush()

    return guest


def create_manual_booking(
    db: Session,
    organization_id: str,
    booking_in: ReservationCreate,
    actor_name: str = "Host"
) -> Reservation:
    """
    Creates a manual reservation with full validation, capacity checks, conflict checking,
    decimal calculations, and automatic guest form token generation.
    """
    # 1. Validate property
    prop = db.execute(
        select(Property).where(
            Property.id == booking_in.property_id,
            Property.organization_id == organization_id
        )
    ).scalar_one_or_none()
    if not prop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Property not found")

    # 2. Validate unit & capacity
    unit = None
    if booking_in.unit_id:
        unit = db.execute(
            select(PropertyUnit).where(
                PropertyUnit.id == booking_in.unit_id,
                PropertyUnit.property_id == prop.id
            )
        ).scalar_one_or_none()
        if not unit:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Property unit not found")
    capacity = unit.max_guests if unit is not None else prop.max_guests
    if booking_in.number_of_guests < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Guest count must be at least one"
        )
    if capacity is not None and booking_in.number_of_guests > capacity:
        capacity_label = "unit" if unit is not None else "property"
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Guest count ({booking_in.number_of_guests}) exceeds {capacity_label} maximum capacity of {capacity}"
        )

    # 3. Check dates & overlapping conflicts
    conflicts = check_booking_conflicts(
        db=db,
        organization_id=organization_id,
        property_id=booking_in.property_id,
        check_in_date=booking_in.check_in_date,
        check_out_date=booking_in.check_out_date,
        unit_id=booking_in.unit_id
    )

    has_conflict = len(conflicts) > 0
    if has_conflict:
        if not booking_in.override_conflict:
            conflict_names = ", ".join([f"{c.guest_name} ({c.check_in_date} to {c.check_out_date})" for c in conflicts])
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Overlapping booking detected with: {conflict_names}. Must provide explicit override reason to proceed."
            )
        if not booking_in.conflict_override_reason or len(booking_in.conflict_override_reason.strip()) < 3:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Conflict override requires a specific reason of at least 3 characters."
            )

    # 4. Decimal rate calculations
    nights = (booking_in.check_out_date - booking_in.check_in_date).days
    if nights <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Stay must be at least 1 night")

    nightly_rate = Decimal(str(
        booking_in.nightly_rate if booking_in.nightly_rate is not None else prop.default_nightly_rate
    ))
    base_amount = nightly_rate * Decimal(nights)
    cleaning_fee = Decimal(str(booking_in.cleaning_fee or Decimal("0.00")))
    service_fee = Decimal(str(booking_in.service_fee or Decimal("0.00")))
    discount_amount = Decimal(str(booking_in.discount_amount or Decimal("0.00")))

    # Compute tax if not provided
    if booking_in.tax_amount is not None:
        tax_amount = Decimal(str(booking_in.tax_amount))
    else:
        subtotal_for_tax = max(Decimal("0.00"), base_amount + cleaning_fee + service_fee - discount_amount)
        tax_amount = (subtotal_for_tax * prop.tax_rate).quantize(Decimal("0.01"))

    total_amount = base_amount + cleaning_fee + service_fee - discount_amount + tax_amount
    amount_paid = Decimal("0.00")
    balance_due = total_amount

    # Agent referral calculation
    has_agent = booking_in.has_agent or (booking_in.agent_name is not None and len(booking_in.agent_name.strip()) > 0)
    agent_pct = Decimal(str(booking_in.agent_commission_percent or "0.00"))
    if has_agent and agent_pct > 0:
        agent_comm_amt = (total_amount * (agent_pct / Decimal("100.00"))).quantize(Decimal("0.01"))
    else:
        agent_comm_amt = Decimal("0.00")
    net_host_amt = total_amount - agent_comm_amt

    # 5. Primary Guest
    guest = get_or_create_guest(
        db=db,
        organization_id=organization_id,
        first_name=booking_in.guest_first_name,
        last_name=booking_in.guest_last_name,
        email=booking_in.guest_email,
        phone=booking_in.guest_phone
    )

    # 6. Create Reservation
    reservation = Reservation(
        organization_id=organization_id,
        property_id=booking_in.property_id,
        unit_id=booking_in.unit_id,
        primary_guest_id=guest.id,
        booking_reference=booking_in.booking_reference,
        booking_source=booking_in.booking_source or "direct",
        reservation_status=booking_in.reservation_status or "confirmed",
        payment_status="unpaid",
        guest_info_status="pending",
        check_in_date=booking_in.check_in_date,
        check_out_date=booking_in.check_out_date,
        check_in_time=booking_in.check_in_time or "15:00",
        check_out_time=booking_in.check_out_time or "11:00",
        number_of_guests=booking_in.number_of_guests,
        number_of_nights=nights,
        nightly_rate=nightly_rate,
        base_amount=base_amount,
        cleaning_fee=cleaning_fee,
        service_fee=service_fee,
        discount_amount=discount_amount,
        tax_amount=tax_amount,
        total_amount=total_amount,
        currency=booking_in.currency or "KES",
        amount_paid=amount_paid,
        balance_due=balance_due,
        has_agent=has_agent,
        agent_name=booking_in.agent_name.strip() if (has_agent and booking_in.agent_name) else None,
        agent_phone=booking_in.agent_phone.strip() if (has_agent and booking_in.agent_phone) else None,
        agent_commission_percent=agent_pct,
        agent_commission_amount=agent_comm_amt,
        net_host_amount=net_host_amt,
        internal_notes=booking_in.internal_notes,
        special_requests=booking_in.special_requests,
        has_conflict=has_conflict,
        conflict_override_reason=booking_in.conflict_override_reason if has_conflict else None,
        conflict_overridden_by=actor_name if has_conflict else None
    )
    db.add(reservation)
    db.flush()

    # 7. Record initial deposit / payment if provided
    if booking_in.initial_payment and booking_in.initial_payment.amount > 0:
        pay_amt = Decimal(str(booking_in.initial_payment.amount))
        payment = Payment(
            organization_id=organization_id,
            reservation_id=reservation.id,
            amount=pay_amt,
            currency=reservation.currency,
            payment_method=booking_in.initial_payment.payment_method or "mpesa",
            transaction_reference=booking_in.initial_payment.transaction_reference,
            is_verified=False,  # manually recorded
            verification_source="manual",
            payment_date=datetime.now(timezone.utc).replace(tzinfo=None),
            notes=booking_in.initial_payment.notes or "Initial booking deposit"
        )
        db.add(payment)
        db.flush()

        # Update reservation payment fields
        reservation.amount_paid += pay_amt
        reservation.balance_due = max(Decimal("0.00"), reservation.total_amount - reservation.amount_paid)
        if reservation.balance_due == 0:
            reservation.payment_status = "paid"
        else:
            reservation.payment_status = "partial"

        # Generate unique receipt
        receipt_no = get_next_sequence_number(db, organization_id, "REC")
        receipt = Receipt(
            organization_id=organization_id,
            payment_id=payment.id,
            receipt_number=receipt_no,
            receipt_date=date.today(),
            amount_received=pay_amt,
            currency=reservation.currency,
            payment_method=payment.payment_method,
            transaction_reference=payment.transaction_reference,
            remaining_balance=reservation.balance_due,
            issued_to_name=f"{guest.first_name} {guest.last_name}",
            issued_by_name=actor_name
        )
        db.add(receipt)
        db.flush()

        log_audit_event(
            db=db,
            organization_id=organization_id,
            entity_type="payment",
            entity_id=payment.id,
            action="deposit_recorded",
            actor_name=actor_name,
            details={"amount": str(pay_amt), "receipt_number": receipt_no, "method": payment.payment_method}
        )

    # 8. Post-confirmation guest registration form token association
    if reservation.reservation_status == "confirmed":
        secure_token = secrets.token_urlsafe(32)
        # Expiry set to 30 days or check-in date + 7 days
        expiry_date = datetime.combine(reservation.check_in_date + timedelta(days=7), datetime.min.time())
        guest_sub = GuestFormSubmission(
            organization_id=organization_id,
            reservation_id=reservation.id,
            token=secure_token,
            token_expires_at=expiry_date,
            token_revoked=False,
            form_status="unopened",
            guest_name=f"{guest.first_name} {guest.last_name}",
            guest_email=guest.email,
            guest_phone=guest.phone
        )
        db.add(guest_sub)
        db.flush()

    # 9. Log Audit Trail
    audit_details = {
        "property_id": reservation.property_id,
        "guest_name": f"{guest.first_name} {guest.last_name}",
        "check_in": str(reservation.check_in_date),
        "check_out": str(reservation.check_out_date),
        "total_amount": str(reservation.total_amount),
        "currency": reservation.currency,
        "source": reservation.booking_source
    }
    if has_conflict:
        audit_details["conflict_overridden"] = True
        audit_details["override_reason"] = booking_in.conflict_override_reason
        log_audit_event(
            db=db,
            organization_id=organization_id,
            entity_type="reservation",
            entity_id=reservation.id,
            action="overridden_conflict",
            actor_name=actor_name,
            details=audit_details
        )
    else:
        log_audit_event(
            db=db,
            organization_id=organization_id,
            entity_type="reservation",
            entity_id=reservation.id,
            action="created_manual_booking",
            actor_name=actor_name,
            details=audit_details
        )

    db.commit()
    db.refresh(reservation)
    return reservation


def update_reservation(
    db: Session,
    organization_id: str,
    reservation_id: str,
    update_in: ReservationUpdate,
    actor_name: str = "Host"
) -> Reservation:
    """Updates permitted details on a reservation with recalculations and conflict checks."""
    reservation = db.execute(
        select(Reservation).where(
            Reservation.id == reservation_id,
            Reservation.organization_id == organization_id
        )
    ).scalar_one_or_none()
    if not reservation:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reservation not found")

    new_check_in = update_in.check_in_date or reservation.check_in_date
    new_check_out = update_in.check_out_date or reservation.check_out_date
    new_unit_id = update_in.unit_id if update_in.unit_id is not None else reservation.unit_id
    unit = None
    if new_unit_id:
        unit = db.scalar(
            select(PropertyUnit).where(
                PropertyUnit.id == new_unit_id,
                PropertyUnit.property_id == reservation.property_id,
            )
        )
        if unit is None:
            raise HTTPException(404, "Unit not found for this property")

    guest_count = (
        update_in.number_of_guests
        if update_in.number_of_guests is not None
        else reservation.number_of_guests
    )
    if guest_count < 1:
        raise HTTPException(400, "Guest count must be at least one")
    prop = db.scalar(select(Property).where(Property.id == reservation.property_id))
    capacity = unit.max_guests if unit is not None else prop.max_guests
    if capacity is not None and guest_count > capacity:
        capacity_label = "unit" if unit is not None else "property"
        raise HTTPException(
            400,
            f"Guest count ({guest_count}) exceeds {capacity_label} maximum capacity of {capacity}",
        )

    dates_changed = (new_check_in != reservation.check_in_date) or (new_check_out != reservation.check_out_date) or (new_unit_id != reservation.unit_id)

    if dates_changed:
        conflicts = check_booking_conflicts(
            db=db,
            organization_id=organization_id,
            property_id=reservation.property_id,
            check_in_date=new_check_in,
            check_out_date=new_check_out,
            unit_id=new_unit_id,
            exclude_reservation_id=reservation.id
        )
        if len(conflicts) > 0:
            if not update_in.override_conflict:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Updated dates cause a conflict. Provide override reason to proceed."
                )
            if not update_in.conflict_override_reason or len(update_in.conflict_override_reason.strip()) < 3:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Conflict override reason is required."
                )
            reservation.has_conflict = True
            reservation.conflict_override_reason = update_in.conflict_override_reason
            reservation.conflict_overridden_by = actor_name
            log_audit_event(
                db=db,
                organization_id=organization_id,
                entity_type="reservation",
                entity_id=reservation.id,
                action="overridden_conflict",
                actor_name=actor_name,
                details={"reason": update_in.conflict_override_reason, "new_dates": f"{new_check_in} to {new_check_out}"}
            )
        else:
            reservation.has_conflict = False
            reservation.conflict_override_reason = None
            reservation.conflict_overridden_by = None

        reservation.check_in_date = new_check_in
        reservation.check_out_date = new_check_out
        reservation.unit_id = new_unit_id
        reservation.number_of_nights = (new_check_out - new_check_in).days

    if update_in.number_of_guests is not None:
        reservation.number_of_guests = update_in.number_of_guests
    if update_in.check_in_time is not None:
        reservation.check_in_time = update_in.check_in_time
    if update_in.check_out_time is not None:
        reservation.check_out_time = update_in.check_out_time
    if update_in.booking_source is not None:
        reservation.booking_source = update_in.booking_source
    if update_in.booking_reference is not None:
        reservation.booking_reference = update_in.booking_reference
    if update_in.internal_notes is not None:
        reservation.internal_notes = update_in.internal_notes
    if update_in.special_requests is not None:
        reservation.special_requests = update_in.special_requests

    # Rates recalculation
    if update_in.nightly_rate is not None:
        reservation.nightly_rate = Decimal(str(update_in.nightly_rate))
    if update_in.cleaning_fee is not None:
        reservation.cleaning_fee = Decimal(str(update_in.cleaning_fee))
    if update_in.service_fee is not None:
        reservation.service_fee = Decimal(str(update_in.service_fee))
    if update_in.discount_amount is not None:
        reservation.discount_amount = Decimal(str(update_in.discount_amount))

    reservation.base_amount = reservation.nightly_rate * Decimal(reservation.number_of_nights)
    if update_in.tax_amount is not None:
        reservation.tax_amount = Decimal(str(update_in.tax_amount))
    elif dates_changed or update_in.nightly_rate is not None:
        subtotal_for_tax = max(Decimal("0.00"), reservation.base_amount + reservation.cleaning_fee + reservation.service_fee - reservation.discount_amount)
        reservation.tax_amount = (subtotal_for_tax * prop.tax_rate).quantize(Decimal("0.01"))

    reservation.total_amount = reservation.base_amount + reservation.cleaning_fee + reservation.service_fee - reservation.discount_amount + reservation.tax_amount
    reservation.balance_due = max(Decimal("0.00"), reservation.total_amount - reservation.amount_paid)

    # Agent Referral / Commission update
    if update_in.has_agent is not None:
        reservation.has_agent = update_in.has_agent
    if update_in.agent_name is not None:
        reservation.agent_name = update_in.agent_name.strip() if update_in.agent_name else None
    if update_in.agent_phone is not None:
        reservation.agent_phone = update_in.agent_phone.strip() if update_in.agent_phone else None
    if update_in.agent_commission_percent is not None:
        reservation.agent_commission_percent = Decimal(str(update_in.agent_commission_percent))

    if reservation.has_agent and reservation.agent_commission_percent > 0:
        reservation.agent_commission_amount = (reservation.total_amount * (reservation.agent_commission_percent / Decimal("100.00"))).quantize(Decimal("0.01"))
    else:
        reservation.agent_commission_amount = Decimal("0.00")
    reservation.net_host_amount = reservation.total_amount - reservation.agent_commission_amount

    log_audit_event(
        db=db,
        organization_id=organization_id,
        entity_type="reservation",
        entity_id=reservation.id,
        action="updated_reservation",
        actor_name=actor_name,
        details={"total_amount": str(reservation.total_amount), "balance_due": str(reservation.balance_due)}
    )

    db.commit()
    db.refresh(reservation)
    return reservation


def cancel_reservation(
    db: Session,
    organization_id: str,
    reservation_id: str,
    reason: Optional[str] = None,
    actor_name: str = "Host"
) -> Reservation:
    """Cancels a reservation and records in audit log."""
    reservation = db.execute(
        select(Reservation).where(
            Reservation.id == reservation_id,
            Reservation.organization_id == organization_id
        )
    ).scalar_one_or_none()
    if not reservation:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reservation not found")

    reservation.reservation_status = "cancelled"
    log_audit_event(
        db=db,
        organization_id=organization_id,
        entity_type="reservation",
        entity_id=reservation.id,
        action="cancelled_reservation",
        actor_name=actor_name,
        details={"reason": reason or "Cancelled by host"}
    )
    db.commit()
    db.refresh(reservation)
    return reservation
