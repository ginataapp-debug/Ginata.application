import secrets
from datetime import timezone, datetime, timedelta
from typing import Optional, Dict, Any, List
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select

from backend.app.models.models import (
    Reservation, Guest, GuestFormSubmission, GuestForm, AuditLog
)
from backend.app.schemas.schemas import (
    PublicGuestFormView, PublicGuestFormSubmitRequest, SubmissionReviewRequest
)
from backend.app.services.audit_service import log_audit_event

def get_or_generate_reservation_form_token(
    db: Session,
    organization_id: str,
    reservation_id: str,
    days_valid: int = 30
) -> GuestFormSubmission:
    """Gets existing active token or creates a new secure unguessable token for reservation."""
    res = db.execute(
        select(Reservation).where(
            Reservation.id == reservation_id,
            Reservation.organization_id == organization_id
        )
    ).scalar_one_or_none()
    if not res:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reservation not found")

    submission = db.execute(
        select(GuestFormSubmission).where(
            GuestFormSubmission.reservation_id == reservation_id,
            GuestFormSubmission.token_revoked == False
        ).order_by(GuestFormSubmission.created_at.desc())
    ).scalars().first()

    if not submission:
        token = secrets.token_urlsafe(32)
        expiry = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=days_valid)
        guest_name = f"{res.primary_guest.first_name} {res.primary_guest.last_name}" if res.primary_guest else ""
        submission = GuestFormSubmission(
            organization_id=organization_id,
            reservation_id=reservation_id,
            token=token,
            token_expires_at=expiry,
            token_revoked=False,
            form_status="unopened",
            guest_name=guest_name,
            guest_email=res.primary_guest.email if res.primary_guest else None,
            guest_phone=res.primary_guest.phone if res.primary_guest else None
        )
        db.add(submission)
        db.commit()
        db.refresh(submission)

    return submission


def revoke_form_token(
    db: Session,
    organization_id: str,
    token: str,
    actor_name: str = "Host"
) -> GuestFormSubmission:
    """Revokes a public guest form link."""
    submission = db.execute(
        select(GuestFormSubmission).where(
            GuestFormSubmission.token == token,
            GuestFormSubmission.organization_id == organization_id
        )
    ).scalar_one_or_none()
    if not submission:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Guest form submission not found")

    submission.token_revoked = True
    log_audit_event(
        db=db,
        organization_id=organization_id,
        entity_type="guest_form",
        entity_id=submission.id,
        action="revoked_token",
        actor_name=actor_name,
        details={"token_prefix": token[:8]}
    )
    db.commit()
    db.refresh(submission)
    return submission


def get_public_form_view(db: Session, token: str) -> PublicGuestFormView:
    """
    Publicly accessible endpoint view: returns safe reservation details without exposing internal IDs.
    Marks form status as 'opened' if it was 'unopened'.
    """
    submission = db.execute(
        select(GuestFormSubmission).where(GuestFormSubmission.token == token)
    ).scalar_one_or_none()
    if not submission:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invalid registration link")

    is_expired = datetime.now(timezone.utc).replace(tzinfo=None) > submission.token_expires_at
    if submission.token_revoked or is_expired:
        return PublicGuestFormView(
            token=token,
            reservation_id=submission.reservation_id,
            property_name="Ginata Estate",
            check_in_date=datetime.now(timezone.utc).replace(tzinfo=None).date(),
            check_out_date=datetime.now(timezone.utc).replace(tzinfo=None).date(),
            number_of_nights=0,
            number_of_guests=0,
            primary_guest_name=submission.guest_name or "",
            form_status="expired" if is_expired else "revoked",
            token_expires_at=submission.token_expires_at,
            is_expired=is_expired,
            is_revoked=submission.token_revoked
        )

    res = submission.reservation
    prop = res.property if res else None

    if submission.form_status == "unopened":
        submission.form_status = "opened"
        db.commit()

    return PublicGuestFormView(
        token=token,
        reservation_id=submission.reservation_id,
        property_name=prop.name if prop else "Ginata Luxury Villa",
        property_address=prop.address if prop else "",
        check_in_date=res.check_in_date if res else datetime.now(timezone.utc).replace(tzinfo=None).date(),
        check_out_date=res.check_out_date if res else datetime.now(timezone.utc).replace(tzinfo=None).date(),
        number_of_nights=res.number_of_nights if res else 1,
        number_of_guests=res.number_of_guests if res else 1,
        primary_guest_name=submission.guest_name or (f"{res.primary_guest.first_name} {res.primary_guest.last_name}" if res and res.primary_guest else ""),
        form_status=submission.form_status,
        token_expires_at=submission.token_expires_at,
        is_expired=False,
        is_revoked=False
    )


def submit_public_guest_form(
    db: Session,
    token: str,
    submit_in: PublicGuestFormSubmitRequest
) -> GuestFormSubmission:
    """
    Validates and processes public guest submission.
    Guarantees idempotency: repeated submissions update the existing submission record.
    Never creates a duplicate reservation!
    Never modifies reservation dates, prices, or status!
    Updates guest profile permitted details and sets reservation guest_info_status.
    """
    # 1. Anti-spam honeypot check
    if submit_in.honeypot and len(submit_in.honeypot.strip()) > 0:
        # Silently reject bots without raising clear trace
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Spam submission rejected")

    # 2. Token lookup
    submission = db.execute(
        select(GuestFormSubmission).where(GuestFormSubmission.token == token)
    ).scalar_one_or_none()
    if not submission:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invalid registration link")

    if submission.token_revoked:
        raise HTTPException(status_code=status.HTTP_410_GONE, detail="This registration link has been revoked by the host")

    if datetime.now(timezone.utc).replace(tzinfo=None) > submission.token_expires_at:
        raise HTTPException(status_code=status.HTTP_410_GONE, detail="This registration link has expired")

    # 3. Associate with confirmed reservation
    reservation = submission.reservation
    if not reservation:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Linked reservation not found")

    # 4. Save submission details idempotently
    submission.submitted_at = datetime.now(timezone.utc).replace(tzinfo=None)
    submission.guest_name = submit_in.guest_name.strip()
    submission.guest_email = submit_in.guest_email.strip().lower() if submit_in.guest_email else submission.guest_email
    submission.guest_phone = submit_in.guest_phone.strip() if submit_in.guest_phone else submission.guest_phone
    submission.eta = submit_in.eta
    submission.flight_number = submit_in.flight_number
    submission.transport_mode = submit_in.transport_mode
    submission.dietary_requirements = submit_in.dietary_requirements
    submission.special_requests = submit_in.special_requests
    submission.id_type = submit_in.id_type
    submission.id_number = submit_in.id_number
    submission.id_photo_url = submit_in.id_photo_url
    submission.companion_details = submit_in.companion_details
    submission.raw_data = submit_in.model_dump(exclude={"honeypot"})

    # Check whether submission needs manual review (e.g. if ID details submitted or special requests)
    needs_review = bool(submit_in.id_number or submit_in.id_photo_url or submit_in.special_requests)
    submission.form_status = "needs_review" if needs_review else "completed"

    # 5. Update guest profile contact details
    primary_guest = reservation.primary_guest
    if primary_guest:
        if submit_in.guest_email and not primary_guest.email:
            primary_guest.email = submit_in.guest_email.strip().lower()
        if submit_in.guest_phone and not primary_guest.phone:
            primary_guest.phone = submit_in.guest_phone.strip()
        if submit_in.id_type and not primary_guest.id_type:
            primary_guest.id_type = submit_in.id_type
        if submit_in.id_number and not primary_guest.id_number_masked:
            # Mask ID for privacy (e.g. keep last 4 chars)
            clean_id = submit_in.id_number.strip()
            masked = f"{'*' * max(0, len(clean_id) - 4)}{clean_id[-4:]}" if len(clean_id) > 4 else clean_id
            primary_guest.id_number_masked = masked

    # 6. Update reservation guest-information status (booking remains confirmed!)
    reservation.guest_info_status = "needs_review" if needs_review else "completed"

    # 7. Record in audit log
    log_audit_event(
        db=db,
        organization_id=submission.organization_id,
        entity_type="guest_form",
        entity_id=submission.id,
        action="guest_form_submitted",
        actor_name=submit_in.guest_name,
        details={
            "reservation_id": reservation.id,
            "guest_info_status": reservation.guest_info_status,
            "eta": submit_in.eta,
            "flight_number": submit_in.flight_number
        }
    )

    db.commit()
    db.refresh(submission)
    return submission


def review_guest_form_submission(
    db: Session,
    organization_id: str,
    submission_id: str,
    review_in: SubmissionReviewRequest,
    actor_name: str = "Host"
) -> GuestFormSubmission:
    """Host reviews submission, updates review notes, and marks status."""
    submission = db.execute(
        select(GuestFormSubmission).where(
            GuestFormSubmission.id == submission_id,
            GuestFormSubmission.organization_id == organization_id
        )
    ).scalar_one_or_none()
    if not submission:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Submission not found")

    new_status = "completed" if review_in.action == "complete" else "needs_review"
    submission.form_status = new_status
    submission.review_notes = review_in.review_notes
    submission.reviewed_by = actor_name
    submission.reviewed_at = datetime.now(timezone.utc).replace(tzinfo=None)

    res = submission.reservation
    if res:
        res.guest_info_status = new_status

    log_audit_event(
        db=db,
        organization_id=organization_id,
        entity_type="guest_form",
        entity_id=submission.id,
        action="guest_form_reviewed",
        actor_name=actor_name,
        details={"status": new_status, "notes": review_in.review_notes}
    )

    db.commit()
    db.refresh(submission)
    return submission
